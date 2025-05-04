import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:airplan/services/websocket_service.dart';
import 'package:airplan/services/api_config.dart';

// Mocks
class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

class MockPreferences extends Mock implements SharedPreferences {}

class MockApiConfig extends Mock implements ApiConfig {}

class MockChannelFactory extends Mock implements WebSocketChannelFactory {}

// Fake channel to simulate WebSocket via mocktail
class FakeWebSocketChannel extends Fake implements WebSocketChannel {
  final StreamController<String> controller =
      StreamController<String>.broadcast();
  @override
  Stream get stream => controller.stream;
  @override
  WebSocketSink get sink => FakeWebSocketSink(controller);
}

class FakeWebSocketSink extends Fake implements WebSocketSink {
  final StreamController<String> _ctrl;
  FakeWebSocketSink(this._ctrl);
  @override
  void add(message) => _ctrl.add(message as String);
  @override
  Future close([int? code, String? reason]) => _ctrl.close();
}

void main() {
  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;
  late MockPreferences mockPrefs;
  late MockApiConfig mockApi;
  late MockChannelFactory mockFactory;
  late FakeWebSocketChannel fakeChannel;
  late WebSocketService service;

  setUpAll(() {
    registerFallbackValue(Uri());
  });

  setUp(() async {
    mockAuth = MockFirebaseAuth();
    mockUser = MockUser();
    when(() => mockAuth.currentUser).thenReturn(mockUser);
    when(
      () => mockAuth.authStateChanges(),
    ).thenAnswer((_) => Stream<User?>.value(mockUser));
    when(() => mockUser.displayName).thenReturn('user1');
    when(() => mockUser.email).thenReturn('email1');

    mockPrefs = MockPreferences();
    when(() => mockPrefs.getString('websocket_client_id')).thenReturn('cid1');
    when(() => mockPrefs.setString(any(), any())).thenAnswer((_) async => true);

    mockApi = MockApiConfig();
    when(() => mockApi.baseUrl).thenReturn('http://example.com');

    fakeChannel = FakeWebSocketChannel();
    mockFactory = MockChannelFactory();
    when(() => mockFactory.connect(any())).thenReturn(fakeChannel);

    service = WebSocketService(
      auth: mockAuth,
      preferences: mockPrefs,
      apiConfig: mockApi,
      channelFactory: mockFactory,
    );
  });

  test('connect uses channelFactory and sets isConnected', () {
    service.connect();
    final expectedUri = Uri.parse(
      'ws://example.com/ws?username=user1&email=email1&clientId=cid1',
    );
    verify(() => mockFactory.connect(expectedUri)).called(1);
    expect(service.isConnected, isTrue);
  });

  test('disconnect closes connection and isConnected becomes false', () {
    service.connect();
    expect(service.isConnected, isTrue);
    service.disconnect();
    expect(service.isConnected, isFalse);
  });

  test(
    'profileUpdates emits non-ping messages and filters ping/pong',
    () async {
      service.connect();
      final records = <String>[];
      service.profileUpdates.listen(records.add);

      // Send a normal message
      fakeChannel.controller.add('hello');
      await Future.delayed(Duration.zero);
      expect(records, ['hello']);

      // Send ping and pong, should be ignored
      fakeChannel.controller.add('{"type":"PING"}');
      fakeChannel.controller.add('{"type":"PONG"}');
      await Future.delayed(Duration.zero);
      expect(records, ['hello']);

      // Another message
      fakeChannel.controller.add('world');
      await Future.delayed(Duration.zero);
      expect(records, ['hello', 'world']);
    },
  );
}
