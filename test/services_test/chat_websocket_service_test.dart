import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:airplan/services/chat_websocket_service.dart';
import 'package:airplan/services/auth_service.dart';
import 'package:airplan/services/api_config.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Mocks and fakes
class MockAuthService extends Mock implements AuthService {}

class MockUser extends Mock implements User {}

class MockApiConfig extends Mock implements ApiConfig {}

class MockChannelFactory extends Mock implements WebSocketChannelFactory {}

// Fake channel capturing outgoing messages and providing incoming stream
class FakeWebSocketChannel extends Fake
    implements WebSocketChannel, WebSocketSink {
  final StreamController<dynamic> controller =
      StreamController<dynamic>.broadcast();
  final List<String> sentMessages = [];
  @override
  Stream get stream => controller.stream;
  @override
  WebSocketSink get sink => this;
  @override
  void add(message) => sentMessages.add(message as String);
  @override
  Future close([int? code, String? reason]) async {}
}

void main() {
  late MockAuthService mockAuth;
  late MockApiConfig mockApi;
  late MockChannelFactory mockFactory;
  late FakeWebSocketChannel fakeChannel;
  late ChatWebSocketService service;

  setUpAll(() {
    registerFallbackValue(Uri());
  });

  setUp(() {
    mockAuth = MockAuthService();
    mockApi = MockApiConfig();
    mockFactory = MockChannelFactory();
    fakeChannel = FakeWebSocketChannel();

    when(
      () => mockAuth.authStateChanges,
    ).thenAnswer((_) => Stream<User?>.value(null));
    when(() => mockAuth.getCurrentUser()).thenReturn(null);
    when(() => mockApi.baseUrl).thenReturn('http://testserver');
    when(() => mockFactory.connect(any())).thenReturn(fakeChannel);

    service = ChatWebSocketService(
      authService: mockAuth,
      apiConfig: mockApi,
      webSocketChannelFactory: mockFactory,
    );
  });

  group('connectToChat', () {
    test('does not connect when current username is empty', () {
      service.connectToChat('other');
      expect(service.isChatConnected, isFalse);
      verifyNever(() => mockFactory.connect(any()));
    });

    test('connects when authService provides a username', () async {
      // stub a user with displayName
      final user = MockUser();
      when(() => mockAuth.getCurrentUser()).thenReturn(user);
      when(() => user.displayName).thenReturn('me');
      // simulate authStateChanges also
      when(
        () => mockAuth.authStateChanges,
      ).thenAnswer((_) => Stream<User?>.value(user));

      service = ChatWebSocketService(
        authService: mockAuth,
        apiConfig: mockApi,
        webSocketChannelFactory: mockFactory,
      );

      service.connectToChat('otherUser');
      final uri = Uri.parse('ws://testserver/ws/chat/me/otherUser');
      verify(() => mockFactory.connect(uri)).called(1);
      expect(service.isChatConnected, isTrue);
      expect(service.currentChatPartner, 'otherUser');
    });
  });

  group('sendEditMessage', () {
    test('returns false if not connected', () async {
      final result = await service.sendEditMessage('user', '2023-01-01T12:00:00Z', 'Updated content');
      expect(result, isFalse);
    });

    test('sends edit message when connected', () async {
      // Setup connected state
      fakeChannel = FakeWebSocketChannel();
      when(() => mockFactory.connect(any())).thenReturn(fakeChannel);
      final user = MockUser();
      when(() => mockAuth.getCurrentUser()).thenReturn(user);
      when(() => user.displayName).thenReturn('me');
      when(
            () => mockAuth.authStateChanges,
      ).thenAnswer((_) => Stream<User?>.value(user));
      service = ChatWebSocketService(
        authService: mockAuth,
        apiConfig: mockApi,
        webSocketChannelFactory: mockFactory,
      );
      service.connectToChat('other');

      // Send edit message
      final ok = await service.sendEditMessage('other', '2023-01-01T12:00:00Z', 'Updated content');
      expect(ok, isTrue);

      // Check that the fake sink recorded the sent JSON
      final sentMessage = jsonDecode(fakeChannel.sentMessages.single);
      expect(sentMessage['type'], 'EDIT');
      expect(sentMessage['usernameSender'], 'me');
      expect(sentMessage['usernameReceiver'], 'other');
      expect(sentMessage['originalTimestamp'], '2023-01-01T12:00:00Z');
      expect(sentMessage['newContent'], 'Updated content');
    });
  });

  group('incoming edit messages', () {
    test('dispatches valid edit message', () async {
      // Setup connected state
      final user = MockUser();
      when(() => mockAuth.getCurrentUser()).thenReturn(user);
      when(() => user.displayName).thenReturn('me');
      when(
            () => mockAuth.authStateChanges,
      ).thenAnswer((_) => Stream<User?>.value(user));
      service = ChatWebSocketService(
        authService: mockAuth,
        apiConfig: mockApi,
        webSocketChannelFactory: mockFactory,
      );
      service.connectToChat('other');

      // Listen to emitted messages
      final msgs = <Map<String, dynamic>>[];
      service.chatMessages.listen(msgs.add);

      // Simulate incoming edit message
      final editMessage = {
        'type': 'EDIT',
        'usernameSender': 'me',
        'originalTimestamp': '2023-01-01T12:00:00Z',
        'newContent': 'Updated content',
      };
      fakeChannel.controller.add(jsonEncode(editMessage));
      await Future.delayed(Duration.zero);

      // Verify the emitted message
      expect(msgs.length, 1);
      expect(msgs.first['type'], 'EDIT');
      expect(msgs.first['usernameSender'], 'me');
      expect(msgs.first['originalTimestamp'], '2023-01-01T12:00:00Z');
      expect(msgs.first['newContent'], 'Updated content');
    });
  });

  group('sendChatMessage', () {
    test('returns false if not connected', () async {
      final result = await service.sendChatMessage('user', 'hi', DateTime.now());
      expect(result, isFalse);
    });

    test('sends message when connected', () async {
      // Setup connected state
      fakeChannel = FakeWebSocketChannel();
      when(() => mockFactory.connect(any())).thenReturn(fakeChannel);
      final user = MockUser();
      when(() => mockAuth.getCurrentUser()).thenReturn(user);
      when(() => user.displayName).thenReturn('me');
      when(
        () => mockAuth.authStateChanges,
      ).thenAnswer((_) => Stream<User?>.value(user));
      service = ChatWebSocketService(
        authService: mockAuth,
        apiConfig: mockApi,
        webSocketChannelFactory: mockFactory,
      );
      service.connectToChat('other');
      // send
      final ok = await service.sendChatMessage('other', 'hello', DateTime.now());
      expect(ok, isTrue);
      // check that the fake sink recorded the sent JSON
      expect(fakeChannel.sentMessages.single, contains('"missatge":"hello"'));
    });
  });

  group('incoming messages', () {
    test('dispatches valid chat message', () async {
      // connect and listen
      final user = MockUser();
      when(() => mockAuth.getCurrentUser()).thenReturn(user);
      when(() => user.displayName).thenReturn('me');
      when(
        () => mockAuth.authStateChanges,
      ).thenAnswer((_) => Stream<User?>.value(user));
      service = ChatWebSocketService(
        authService: mockAuth,
        apiConfig: mockApi,
        webSocketChannelFactory: mockFactory,
      );
      service.connectToChat('other');
      final msgs = <Map<String, dynamic>>[];
      service.chatMessages.listen(msgs.add);

      final chatMap = {
        'usernameSender': 'me',
        'usernameReceiver': 'other',
        'dataEnviament': DateTime.now().toIso8601String(),
        'missatge': 'hi',
      };
      fakeChannel.controller.add(jsonEncode(chatMap));
      await Future.delayed(Duration.zero);
      expect(msgs.length, 1);
      expect(msgs.first['missatge'], 'hi');
    });

    test('filters ping messages', () async {
      // setup
      final user = MockUser();
      when(() => mockAuth.getCurrentUser()).thenReturn(user);
      when(() => user.displayName).thenReturn('me');
      when(
        () => mockAuth.authStateChanges,
      ).thenAnswer((_) => Stream<User?>.value(user));
      service = ChatWebSocketService(
        authService: mockAuth,
        apiConfig: mockApi,
        webSocketChannelFactory: mockFactory,
      );
      service.connectToChat('other');
      final msgs = <Map<String, dynamic>>[];
      service.chatMessages.listen(msgs.add);
      // send ping
      fakeChannel.controller.add('{"type":"PING"}');
      await Future.delayed(Duration.zero);
      expect(msgs, isEmpty);
    });

    test('emits disconnected on channel close', () async {
      // setup
      final user = MockUser();
      when(() => mockAuth.getCurrentUser()).thenReturn(user);
      when(() => user.displayName).thenReturn('me');
      when(
        () => mockAuth.authStateChanges,
      ).thenAnswer((_) => Stream<User?>.value(user));
      service = ChatWebSocketService(
        authService: mockAuth,
        apiConfig: mockApi,
        webSocketChannelFactory: mockFactory,
      );
      service.connectToChat('other');
      final msgs = <Map<String, dynamic>>[];
      service.chatMessages.listen(msgs.add);
      // close channel
      await fakeChannel.controller.close();
      await Future.delayed(Duration.zero);
      expect(msgs.single, {'type': 'disconnected'});
    });
  });
}
