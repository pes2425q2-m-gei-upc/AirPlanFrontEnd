import 'dart:async';
import 'dart:io'; // Necessary for HttpOverrides
import 'dart:convert'; // Necessary for jsonEncode

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:http/http.dart' as http; // Imported for MockClient in @GenerateMocks

import 'package:airplan/services/api_config.dart';
import 'package:airplan/services/auth_service.dart';
import 'package:airplan/services/chat_service.dart';
import 'package:airplan/services/chat_websocket_service.dart';
import 'package:airplan/chat_detail_page.dart';

import 'report_users_test.mocks.dart';

class FakeUserForTest {
  final String? displayName;

  FakeUserForTest({
    this.displayName,
  });
}

class MockHttpClient extends Mock implements HttpClient {}
class MockHttpClientRequest extends Mock implements HttpClientRequest {}
class MockHttpClientResponse extends Mock implements HttpClientResponse {}
class MockHttpHeaders extends Mock implements HttpHeaders {}

@GenerateMocks([
  AuthService,
  ChatWebSocketService,
])
void main() {
  final Map<String, Map<String, String>> translations = {
    'en': {
      'Reportar usuario': 'Report User',
      'report_user': 'Report @{args[0]}',
      'report_reason_placeholder': 'Reason for reporting...',
      'report': 'Report',
      'cancel': 'Cancel',
      'please_introduce_reason': 'Please provide a reason for the report.',
      'gracias_reportar': 'Thanks for reporting {args[0]}! Our team will review the situation.',
      'ya_reportado': 'You have already reported this user. Our administrators will review the report as soon as possible.',
      'no_se_pudo_reportar': 'Could not report user. Please try again later.',
      'error_reportar_usuario_ex': 'Error reporting user: {args[0]}',
    },
    'es': {
      'Reportar usuario': 'Reportar usuario',
      'report_user': 'Reportar a @{args[0]}',
      'report_reason_placeholder': 'Motivo del reporte...',
      'report': 'Reportar',
      'cancel': 'Cancelar',
      'please_introduce_reason': 'Por favor, introduce un motivo para el reporte.',
      'gracias_reportar': '¡Gracias por reportar a {args[0]}! Nuestro equipo revisará la situación.',
      'ya_reportado': 'Ya has reportado a este usuario, uno de nuestros administradores revisará el reporte lo antes posible.',
      'no_se_pudo_reportar': 'No se pudo reportar al usuario. Inténtalo de nuevo más tarde.',
      'error_reportar_usuario_ex': 'Error al reportar usuario: {args[0]}',
    }
  };

  Future <void> ensureInitialized() async {
    await EasyLocalization.ensureInitialized();
  }

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    EasyLocalization.logger.enableBuildModes = [];
    ensureInitialized();
  });

  Widget createTestableWidget(Widget child, {Locale locale = const Locale('es')}) {
    return MaterialApp(
      home: EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('es')],
        path: 'assets/translations',
        fallbackLocale: const Locale('es'),
        assetLoader: const RootBundleAssetLoader(),
        useOnlyLangCode: true,
        child: Builder(
            builder: (context) {
              context.setLocale(locale);
              return child;
            }
        ),
      ),
    );
  }

  group('ChatService - reportUser Tests', () {
    late MockHttpClient mockHttpClient;
    late MockHttpClientRequest mockHttpClientRequest;
    late MockHttpClientResponse mockHttpClientResponse;
    late MockHttpHeaders mockHttpHeaders;

    late ChatService chatService;
    late MockAuthService mockAuthService;
    late MockChatWebSocketService mockChatWebSocketService;
    late String originalApiConfigBaseUrl;

    setUp(() {
      mockHttpClient = MockHttpClient();
      mockHttpClientRequest = MockHttpClientRequest();
      mockHttpClientResponse = MockHttpClientResponse();
      mockHttpHeaders = MockHttpHeaders();

      mockAuthService = MockAuthService();
      mockChatWebSocketService = MockChatWebSocketService();

      final apiConfig = ApiConfig();
      originalApiConfigBaseUrl = apiConfig.baseUrl;
      apiConfig.initialize(customUrl: 'http://fake.api.test');

      chatService = ChatService(
        authService: mockAuthService,
        chatWebSocketService: mockChatWebSocketService,
      );
    });

    tearDown(() {
      if (originalApiConfigBaseUrl.isEmpty) {
        ApiConfig().initialize();
      } else {
        ApiConfig().initialize(customUrl: originalApiConfigBaseUrl);
      }
    });

    void setupMockHttpResponse({
      required int statusCode,
      String body = '',
      required MockHttpClient mockHttpClient,
      required MockHttpClientRequest mockHttpClientRequest,
      required MockHttpClientResponse mockHttpClientResponse,
      required MockHttpHeaders mockHttpHeaders,
    }) {
      when(mockHttpClient.postUrl(
          Uri.parse('http://any.url.com')
      )).thenAnswer((_) async => mockHttpClientRequest);

      when(mockHttpClientRequest.headers).thenReturn(mockHttpHeaders);
      when(mockHttpClientRequest.close()).thenAnswer((_) async => mockHttpClientResponse);
      when(mockHttpClientResponse.statusCode).thenReturn(statusCode);
      when(mockHttpClientResponse.listen(
        any,
        onDone: anyNamed('onDone'),
        onError: anyNamed('onError'),
        cancelOnError: anyNamed('cancelOnError'),
      )).thenAnswer((Invocation invocation) {
        final void Function(List<int>) onData = invocation.positionalArguments[0];
        onData(utf8.encode(body));
        final void Function()? onDone = invocation.namedArguments[#onDone];
        if (onDone != null) {
          onDone();
        }
        return MockStreamSubscription<List<int>>();
      });
    }

    test('reportUser devuelve true en éxito (201)', () async {
      setupMockHttpResponse(
        statusCode: 201,
        mockHttpClient: mockHttpClient,
        mockHttpClientRequest: mockHttpClientRequest,
        mockHttpClientResponse: mockHttpClientResponse,
        mockHttpHeaders: mockHttpHeaders,
      );

      final result = await HttpOverrides.runZoned(
            () => chatService.reportUser(
          reportedUsername: 'reportedUser',
          reporterUsername: 'reporterUser',
          reason: 'Test reason',
        ),
        createHttpClient: (_) => mockHttpClient,
      );
      expect(result, true);
    });

    test('reportUser devuelve "already_reported" en conflicto (409)', () async {
      setupMockHttpResponse(
        statusCode: 409,
        mockHttpClient: mockHttpClient,
        mockHttpClientRequest: mockHttpClientRequest,
        mockHttpClientResponse: mockHttpClientResponse,
        mockHttpHeaders: mockHttpHeaders,
      );

      final result = await HttpOverrides.runZoned(
            () => chatService.reportUser(
          reportedUsername: 'reportedUser',
          reporterUsername: 'reporterUser',
          reason: 'Test reason',
        ),
        createHttpClient: (_) => mockHttpClient,
      );
      expect(result, 'already_reported');
    });

    test('reportUser devuelve false en otro error del servidor (ej. 500)', () async {
      setupMockHttpResponse(
        statusCode: 500,
        body: 'Server Error',
        mockHttpClient: mockHttpClient,
        mockHttpClientRequest: mockHttpClientRequest,
        mockHttpClientResponse: mockHttpClientResponse,
        mockHttpHeaders: mockHttpHeaders,
      );

      final result = await HttpOverrides.runZoned(
            () => chatService.reportUser(
          reportedUsername: 'reportedUser',
          reporterUsername: 'reporterUser',
          reason: 'Test reason',
        ),
        createHttpClient: (_) => mockHttpClient,
      );
      expect(result, false);
    });

    test('reportUser devuelve false en excepción del cliente http', () async {
      when(mockHttpClient.postUrl(
          Uri.parse('http://any.url.com')
      )).thenThrow(Exception('Network error'));

      final result = await HttpOverrides.runZoned(
            () => chatService.reportUser(
          reportedUsername: 'reportedUser',
          reporterUsername: 'reporterUser',
          reason: 'Test reason',
        ),
        createHttpClient: (_) => mockHttpClient,
      );
      expect(result, false);
    });
  });

  group('ChatDetailPage - Funcionalidad de Reportar Usuario Tests', () {
    late MockAuthService mockAuthService;
    late MockChatService mockChatService;
    late MockChatWebSocketService mockChatWebSocketService;

    const String otherUserUsername = 'testOtherUser';
    const String currentLoggedInUser = 'currentUser';

    setUp(() {
      mockAuthService = MockAuthService();
      mockChatService = MockChatService();
      mockChatWebSocketService = MockChatWebSocketService();

      when(mockAuthService.getCurrentUser())
          .thenReturn(FakeUserForTest(displayName: currentLoggedInUser) as User?);

      when(mockChatWebSocketService.connectToChat(any)).thenAnswer((_) async {});
      when(mockChatWebSocketService.chatMessages).thenAnswer((_) => Stream.empty());

      when(mockChatService.getConversation(any as String)).thenAnswer((_) async => []);
      when(mockChatService.disconnectFromChat()).thenAnswer((_) {});

      when(mockChatService.reportUser(
        reportedUsername: any as String,
        reporterUsername: any as String,
        reason: any as String,
      )).thenAnswer((_) async => false);
    });

    testWidgets('Muestra opción "Reportar usuario" y abre diálogo', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget(
        ChatDetailPage(
          username: otherUserUsername,
          name: 'Test Other User Display Name',
          authService: mockAuthService,
          chatService: mockChatService,
          webSocketService: mockChatWebSocketService,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      final reportOptionFinder = find.text(translations['es']!['Reportar usuario']!);
      expect(reportOptionFinder, findsOneWidget);
      await tester.tap(reportOptionFinder);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text(translations['es']!['report_user']!.replaceFirst('{args[0]}', otherUserUsername)), findsOneWidget);
      expect(find.widgetWithText(TextField, translations['es']!['report_reason_placeholder']!), findsOneWidget);
    });

    testWidgets('Diálogo de reporte: error si razón está vacía', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget(
        ChatDetailPage(
          username: otherUserUsername,
          authService: mockAuthService,
          chatService: mockChatService,
          webSocketService: mockChatWebSocketService,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text(translations['es']!['Reportar usuario']!));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, translations['es']!['report']!));
      await tester.pumpAndSettle();

      verifyNever(mockChatService.reportUser(
          reportedUsername: any as String, reporterUsername: any as String, reason: any as String));

      expect(find.text(translations['es']!['please_introduce_reason']!), findsOneWidget);
    });

    testWidgets('Diálogo de reporte: envía reporte con éxito', (WidgetTester tester) async {
      when(mockChatService.reportUser(
        reportedUsername: otherUserUsername,
        reporterUsername: currentLoggedInUser,
        reason: 'Valid reason for report',
      )).thenAnswer((_) async => true);

      await tester.pumpWidget(createTestableWidget(
        ChatDetailPage(
          username: otherUserUsername,
          authService: mockAuthService,
          chatService: mockChatService,
          webSocketService: mockChatWebSocketService,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text(translations['es']!['Reportar usuario']!));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, translations['es']!['report_reason_placeholder']!), 'Valid reason for report');
      await tester.tap(find.widgetWithText(TextButton, translations['es']!['report']!));
      await tester.pumpAndSettle();

      verify(mockChatService.reportUser(
        reportedUsername: otherUserUsername,
        reporterUsername: currentLoggedInUser,
        reason: 'Valid reason for report',
      )).called(1);

      expect(find.text(translations['es']!['gracias_reportar']!.replaceFirst('{args[0]}', otherUserUsername)), findsOneWidget);
    });

    testWidgets('Diálogo de reporte: maneja caso "ya reportado"', (WidgetTester tester) async {
      when(mockChatService.reportUser(
        reportedUsername: otherUserUsername,
        reporterUsername: currentLoggedInUser,
        reason: 'Another reason',
      )).thenAnswer((_) async => 'already_reported');

      await tester.pumpWidget(createTestableWidget(
        ChatDetailPage(
          username: otherUserUsername,
          authService: mockAuthService,
          chatService: mockChatService,
          webSocketService: mockChatWebSocketService,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text(translations['es']!['Reportar usuario']!));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, translations['es']!['report_reason_placeholder']!), 'Another reason');
      await tester.tap(find.widgetWithText(TextButton, translations['es']!['report']!));
      await tester.pumpAndSettle();

      verify(mockChatService.reportUser(
        reportedUsername: otherUserUsername,
        reporterUsername: currentLoggedInUser,
        reason: 'Another reason',
      )).called(1);
      expect(find.text(translations['es']!['ya_reportado']!), findsOneWidget);
    });

    testWidgets('Diálogo de reporte: maneja error genérico del servicio', (WidgetTester tester) async {
      when(mockChatService.reportUser(
        reportedUsername: otherUserUsername,
        reporterUsername: currentLoggedInUser,
        reason: 'Reason for failure',
      )).thenAnswer((_) async => false);

      await tester.pumpWidget(createTestableWidget(
        ChatDetailPage(
          username: otherUserUsername,
          authService: mockAuthService,
          chatService: mockChatService,
          webSocketService: mockChatWebSocketService,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text(translations['es']!['Reportar usuario']!));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, translations['es']!['report_reason_placeholder']!), 'Reason for failure');
      await tester.tap(find.widgetWithText(TextButton, translations['es']!['report']!));
      await tester.pumpAndSettle();

      verify(mockChatService.reportUser(
        reportedUsername: otherUserUsername,
        reporterUsername: currentLoggedInUser,
        reason: 'Reason for failure',
      )).called(1);
      expect(find.text(translations['es']!['no_se_pudo_reportar']!), findsOneWidget);
    });

    testWidgets('Diálogo de reporte: maneja excepción del servicio', (WidgetTester tester) async {
      final exceptionMessage = 'Network test error';
      when(mockChatService.reportUser(
        reportedUsername: otherUserUsername,
        reporterUsername: currentLoggedInUser,
        reason: 'Reason for exception',
      )).thenThrow(Exception(exceptionMessage));

      await tester.pumpWidget(createTestableWidget(
        ChatDetailPage(
          username: otherUserUsername,
          authService: mockAuthService,
          chatService: mockChatService,
          webSocketService: mockChatWebSocketService,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text(translations['es']!['Reportar usuario']!));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, translations['es']!['report_reason_placeholder']!), 'Reason for exception');
      await tester.tap(find.widgetWithText(TextButton, translations['es']!['report']!));
      await tester.pumpAndSettle();

      verify(mockChatService.reportUser(
        reportedUsername: otherUserUsername,
        reporterUsername: currentLoggedInUser,
        reason: 'Reason for exception',
      )).called(1);
      expect(find.text(translations['es']!['error_reportar_usuario_ex']!.replaceFirst('{args[0]}', 'Exception: $exceptionMessage')), findsOneWidget);
    });
  }
  );
}

class MockChatService extends Mock implements ChatService {
  @override
  Future<dynamic> reportUser({
    required String reportedUsername,
    required String reporterUsername,
    required String reason,
  }) async {
    return super.noSuchMethod(
      Invocation.method(#reportUser, [], {
        #reportedUsername: reportedUsername,
        #reporterUsername: reporterUsername,
        #reason: reason,
      }),
      returnValue: Future.value(false),
      returnValueForMissingStub: Future.value(false),
    );
  }

  @override
  Future<List<Message>> getConversation(String otherUsername) async {
    return super.noSuchMethod(
      Invocation.method(#getConversation, [otherUsername]),
      returnValue: Future.value(<Message>[]),
      returnValueForMissingStub: Future.value(<Message>[]),
    );
  }

  @override
  void disconnectFromChat() {
    super.noSuchMethod(
      Invocation.method(#disconnectFromChat, []),
      returnValueForMissingStub: null,
    );
  }
}

class MockStreamSubscription<T> extends Mock implements StreamSubscription<T> {}