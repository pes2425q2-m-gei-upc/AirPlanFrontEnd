import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:airplan/services/chat_service.dart';
import 'package:airplan/services/chat_websocket_service.dart';
import 'package:airplan/services/auth_service.dart';

// Mocks
class MockChatWebSocketService extends Mock implements ChatWebSocketService {}

class MockAuthService extends Mock implements AuthService {}

void main() {
  late MockChatWebSocketService mockWS;
  late MockAuthService mockAuth;
  late ChatService chatService;

  // No Firebase initialization needed since AuthService is mocked
  setUpAll(() {
    // empty
  });

  setUp(() {
    mockWS = MockChatWebSocketService();
    mockAuth = MockAuthService();
    chatService = ChatService(
      chatWebSocketService: mockWS,
      authService: mockAuth,
    );
  });

  group('sendMessage', () {
    const other = 'otherUser';
    const content = 'hello';
    var hora = DateTime.now();


    test('returns true when WebSocket sendChatMessage succeeds', () async {
      when(
        () => mockWS.sendChatMessage(other, content, hora),
      ).thenAnswer((_) async => true);

      final result = await chatService.sendMessage(other, content, hora);
      expect(result, isTrue);
      verify(() => mockWS.sendChatMessage(other, content, hora)).called(1);
    });

    test('returns false when WebSocket sendChatMessage fails', () async {
      when(
        () => mockWS.sendChatMessage(other, content, DateTime.now()),
      ).thenAnswer((_) async => false);

      final result = await chatService.sendMessage(other, content, DateTime.now());
      expect(result, isFalse);
    });

    test('returns false on exception', () async {
      when(
        () => mockWS.sendChatMessage(other, content, DateTime.now()),
      ).thenThrow(Exception('fail'));

      final result = await chatService.sendMessage(other, content, DateTime.now());
      expect(result, isFalse);
    });
  });

  group('getConversation', () {
    test('returns empty list when user not logged in', () async {
      when(() => mockAuth.getCurrentUser()).thenReturn(null);

      final conv = await chatService.getConversation('someone');
      expect(conv, isEmpty);
      verify(() => mockAuth.getCurrentUser()).called(1);
    });
  });

  group('getAllChats', () {
    test('returns empty list when user not logged in', () async {
      when(() => mockAuth.getCurrentUser()).thenReturn(null);

      final chats = await chatService.getAllChats();
      expect(chats, isEmpty);
    });
  });

  group('disconnectFromChat', () {
    test('calls disconnectChat on ChatWebSocketService', () {
      chatService.disconnectFromChat();
      verify(() => mockWS.disconnectChat()).called(1);
    });
  });
}
