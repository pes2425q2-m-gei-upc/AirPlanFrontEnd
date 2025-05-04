import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:airplan/services/user_block_service.dart';
import 'package:airplan/services/api_config.dart';
import 'package:airplan/services/chat_websocket_service.dart';
import 'package:airplan/services/auth_service.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

// Generamos las clases mock
@GenerateMocks([ChatWebSocketService, ApiConfig, http.Client, AuthService])
import 'user_block_service_test.mocks.dart';

// --- Mock Firebase Platform Implementation ---
// Mock para FirebaseAppPlatform
class MockFirebaseAppPlatform extends FirebaseAppPlatform
    with MockPlatformInterfaceMixin {
  MockFirebaseAppPlatform() : super('[DEFAULT]', _mockOptions);

  static const FirebaseOptions _mockOptions = FirebaseOptions(
    apiKey: 'mock_api_key',
    appId: 'mock_app_id',
    messagingSenderId: 'mock_sender_id',
    projectId: 'mock_project_id',
  );
}

// Mock para FirebasePlatform
class MockFirebasePlatform extends FirebasePlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<FirebaseAppPlatform> initializeApp({
    String? name,
    FirebaseOptions? options,
  }) async {
    return MockFirebaseAppPlatform();
  }

  @override
  List<FirebaseAppPlatform> get apps => [MockFirebaseAppPlatform()];

  @override
  FirebaseAppPlatform app([String name = defaultFirebaseAppName]) {
    return MockFirebaseAppPlatform();
  }
}

// Clase de prueba para User
class TestUser implements User {
  final String? _email;
  final String? _displayName;
  final String? _uid;

  TestUser({String? email, String? displayName, String? uid})
    : _email = email,
      _displayName = displayName,
      _uid = uid;

  @override
  String? get email => _email;

  @override
  String? get displayName => _displayName;

  @override
  String get uid => _uid ?? 'test-uid';

  // Implementar los métodos restantes con valores predeterminados
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Configurar mocks de Firebase Core
Future<void> setupFirebaseCoreMocks() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Establecer la instancia de plataforma mock antes de llamar a Firebase.initializeApp
  FirebasePlatform.instance = MockFirebasePlatform();

  // Inicializar Firebase - esto usará el MockFirebasePlatform
  await Firebase.initializeApp();
}

void main() async {
  // Configurar Firebase mocks una vez antes de todas las pruebas
  setUpAll(() async {
    await setupFirebaseCoreMocks();
  });

  group('UserBlockService Tests', () {
    late UserBlockService userBlockService;
    late MockChatWebSocketService mockChatWebSocketService;
    late MockApiConfig mockApiConfig;
    late MockClient mockHttpClient;
    late MockAuthService mockAuthService;

    const String userBlocker = 'user1';
    const String userBlocked = 'user2';
    const String baseUrl = 'http://test-api.example.com';

    setUp(() {
      // Inicializamos los mocks
      mockChatWebSocketService = MockChatWebSocketService();
      mockApiConfig = MockApiConfig();
      mockHttpClient = MockClient();
      mockAuthService = MockAuthService();

      // Configuramos el mock de ApiConfig
      when(mockApiConfig.buildUrl(any)).thenAnswer((invocation) {
        final endpoint = invocation.positionalArguments[0] as String;
        return '$baseUrl/$endpoint';
      });

      // Configuramos el mock de AuthService
      when(mockAuthService.getCurrentUsername()).thenReturn(userBlocker);

      // Creamos la instancia de UserBlockService con los mocks inyectados
      userBlockService = UserBlockService(
        chatWebSocketService: mockChatWebSocketService,
        apiConfig: mockApiConfig,
        httpClient: mockHttpClient,
        authService: mockAuthService,
      );
    });

    group('blockUser Tests', () {
      test(
        'blockUser should return true when WebSocket notification succeeds',
        () async {
          // Configuramos el mock para simular un envío exitoso por WebSocket
          when(
            mockChatWebSocketService.sendBlockNotification(userBlocked, true),
          ).thenAnswer((_) async => true);

          // Ejecutamos el método a probar
          final result = await userBlockService.blockUser(
            userBlocker,
            userBlocked,
          );

          // Verificamos el resultado y las interacciones
          expect(result, isTrue);
          verify(
            mockChatWebSocketService.sendBlockNotification(userBlocked, true),
          ).called(1);
          verifyNever(
            mockHttpClient.post(
              any,
              headers: anyNamed('headers'),
              body: anyNamed('body'),
            ),
          );
        },
      );

      test('blockUser should use HTTP fallback when WebSocket fails', () async {
        // Configuramos el mock para simular un fallo en el WebSocket
        when(
          mockChatWebSocketService.sendBlockNotification(userBlocked, true),
        ).thenAnswer((_) async => false);

        // Configuramos el mock para simular una respuesta HTTP exitosa
        when(
          mockHttpClient.post(
            Uri.parse('$baseUrl/api/blocks/create'),
            headers: {'Content-Type': 'application/json'},
            body: anyNamed('body'),
          ),
        ).thenAnswer((_) async => http.Response('{"success": true}', 200));

        // Ejecutamos el método a probar
        final result = await userBlockService.blockUser(
          userBlocker,
          userBlocked,
        );

        // Verificamos el resultado y las interacciones
        expect(result, isTrue);
        verify(
          mockChatWebSocketService.sendBlockNotification(userBlocked, true),
        ).called(1);
        verify(
          mockHttpClient.post(
            Uri.parse('$baseUrl/api/blocks/create'),
            headers: {'Content-Type': 'application/json'},
            body: anyNamed('body'),
          ),
        ).called(1);
      });

      test('blockUser should return false on HTTP error', () async {
        // Configuramos para simular un fallo en el WebSocket
        when(
          mockChatWebSocketService.sendBlockNotification(userBlocked, true),
        ).thenAnswer((_) async => false);

        // Configuramos para simular un error HTTP
        when(
          mockHttpClient.post(
            Uri.parse('$baseUrl/api/blocks/create'),
            headers: {'Content-Type': 'application/json'},
            body: anyNamed('body'),
          ),
        ).thenAnswer((_) async => http.Response('Error', 500));

        // Ejecutamos el método a probar
        final result = await userBlockService.blockUser(
          userBlocker,
          userBlocked,
        );

        // Verificamos el resultado
        expect(result, isFalse);
      });

      test('blockUser should return false on exception', () async {
        // Configuramos para simular una excepción
        when(
          mockChatWebSocketService.sendBlockNotification(userBlocked, true),
        ).thenThrow(Exception('Network error'));

        // Ejecutamos el método a probar
        final result = await userBlockService.blockUser(
          userBlocker,
          userBlocked,
        );

        // Verificamos el resultado
        expect(result, isFalse);
      });
    });

    group('unblockUser Tests', () {
      test(
        'unblockUser should return true when WebSocket notification succeeds',
        () async {
          // Configuramos para simular un envío exitoso por WebSocket
          when(
            mockChatWebSocketService.sendBlockNotification(userBlocked, false),
          ).thenAnswer((_) async => true);

          // Ejecutamos el método a probar
          final result = await userBlockService.unblockUser(
            userBlocker,
            userBlocked,
          );

          // Verificamos el resultado
          expect(result, isTrue);
          verify(
            mockChatWebSocketService.sendBlockNotification(userBlocked, false),
          ).called(1);
          verifyNever(
            mockHttpClient.post(
              any,
              headers: anyNamed('headers'),
              body: anyNamed('body'),
            ),
          );
        },
      );

      test(
        'unblockUser should use HTTP fallback when WebSocket fails',
        () async {
          // Configuramos para simular un fallo en el WebSocket
          when(
            mockChatWebSocketService.sendBlockNotification(userBlocked, false),
          ).thenAnswer((_) async => false);

          // Configuramos para simular una respuesta HTTP exitosa
          when(
            mockHttpClient.post(
              Uri.parse('$baseUrl/api/blocks/remove'),
              headers: {'Content-Type': 'application/json'},
              body: anyNamed('body'),
            ),
          ).thenAnswer((_) async => http.Response('{"success": true}', 200));

          // Ejecutamos el método a probar
          final result = await userBlockService.unblockUser(
            userBlocker,
            userBlocked,
          );

          // Verificamos el resultado
          expect(result, isTrue);
        },
      );
    });

    group('isUserBlocked Tests', () {
      test('isUserBlocked should return true when user is blocked', () async {
        // Configuramos para simular una respuesta donde el usuario está bloqueado
        when(
          mockHttpClient.get(
            Uri.parse('$baseUrl/api/blocks/status/$userBlocker/$userBlocked'),
          ),
        ).thenAnswer((_) async => http.Response('{"isBlocked": true}', 200));

        // Ejecutamos el método a probar
        final result = await userBlockService.isUserBlocked(
          userBlocker,
          userBlocked,
        );

        // Verificamos el resultado
        expect(result, isTrue);
      });

      test(
        'isUserBlocked should return false when user is not blocked',
        () async {
          // Configuramos para simular una respuesta donde el usuario no está bloqueado
          when(
            mockHttpClient.get(
              Uri.parse('$baseUrl/api/blocks/status/$userBlocker/$userBlocked'),
            ),
          ).thenAnswer((_) async => http.Response('{"isBlocked": false}', 200));

          // Ejecutamos el método a probar
          final result = await userBlockService.isUserBlocked(
            userBlocker,
            userBlocked,
          );

          // Verificamos el resultado
          expect(result, isFalse);
        },
      );

      test('isUserBlocked should return false on API error', () async {
        // Configuramos para simular un error en la API
        when(
          mockHttpClient.get(
            Uri.parse('$baseUrl/api/blocks/status/$userBlocker/$userBlocked'),
          ),
        ).thenAnswer((_) async => http.Response('Error', 500));

        // Ejecutamos el método a probar
        final result = await userBlockService.isUserBlocked(
          userBlocker,
          userBlocked,
        );

        // Verificamos el resultado
        expect(result, isFalse);
      });
    });

    group('getBlockedUsers Tests', () {
      test('getBlockedUsers should return list of blocked users', () async {
        // Lista simulada de usuarios bloqueados
        final mockedBlockedUsers = [
          {'username': 'blockedUser1', 'email': 'blocked1@example.com'},
          {'username': 'blockedUser2', 'email': 'blocked2@example.com'},
        ];

        // Configuramos para simular una respuesta con la lista de usuarios
        final String email = 'test@example.com';
        when(
          mockHttpClient.get(Uri.parse('$baseUrl/api/blocks/list/$email')),
        ).thenAnswer(
          (_) async => http.Response(jsonEncode(mockedBlockedUsers), 200),
        );

        // Ejecutamos el método a probar
        final result = await userBlockService.getBlockedUsers(email);

        // Verificamos el resultado
        expect(result, equals(mockedBlockedUsers));
      });

      test('getBlockedUsers should return empty list on API error', () async {
        // Configuramos para simular un error en la API
        final String email = 'test@example.com';
        when(
          mockHttpClient.get(Uri.parse('$baseUrl/api/blocks/list/$email')),
        ).thenAnswer((_) async => http.Response('Error', 500));

        // Ejecutamos el método a probar
        final result = await userBlockService.getBlockedUsers(email);

        // Verificamos el resultado
        expect(result, isEmpty);
      });
    });

    group('Auth Methods Tests', () {
      test('getCurrentUserEmail should return email from authService', () {
        // Creamos un TestUser en lugar de MockUser
        final testUser = TestUser(
          email: 'user1@example.com',
          displayName: 'User One',
        );

        // Configuramos el mock de AuthService para devolver nuestro TestUser
        when(mockAuthService.getCurrentUser()).thenReturn(testUser);

        // Ejecutamos el método a probar
        final email = userBlockService.getCurrentUserEmail();

        // Verificamos el resultado
        expect(email, equals('user1@example.com'));
      });

      test('getCurrentUsername should return username from authService', () {
        // Configuramos el mock para devolver un username
        when(mockAuthService.getCurrentUsername()).thenReturn('testUsername');

        // Ejecutamos el método a probar
        final username = userBlockService.getCurrentUsername();

        // Verificamos el resultado
        expect(username, equals('testUsername'));
      });
    });
  });
}
