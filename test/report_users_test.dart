import 'dart:typed_data';
import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:airplan/services/chat_service.dart';
import 'package:airplan/services/auth_service.dart';
import 'package:airplan/services/chat_websocket_service.dart';

// A minimal fake User to satisfy AuthService.getCurrentUser()
class FakeUser extends Mock implements User {
  final String name;
  FakeUser(this.name);
  @override
  String? get displayName => name;
}

// Mock AuthService instead of extending it
class MockAuthService extends Mock implements AuthService {
  final FakeUser _user = FakeUser('reporterUser');

  @override
  User? getCurrentUser() => _user;
}

// No-op WebSocket service
// Replace the simple extension with a proper mock
class MockChatWebSocketService extends Mock implements ChatWebSocketService {}

void main() {
  late ChatService chatService;
  late MockAuthService mockAuth; // Renamed from fakeAuth
  late MockChatWebSocketService mockWs; // Renamed from fakeWs

  setUp(() {
    mockAuth = MockAuthService();
    mockWs = MockChatWebSocketService();
    chatService = ChatService(
      authService: mockAuth,
      chatWebSocketService: mockWs,
    );
  });

  // Also update any references in the tests:
  Future<dynamic> runWithClient(HttpClient client) {
    return HttpOverrides.runZoned(
          () => chatService.reportUser(
        reportedUsername: 'otherUser',
        reporterUsername: mockAuth.getCurrentUser()!.displayName!, // Updated
        reason: 'reason',
      ),
      createHttpClient: (_) => client,
    );
  }

  test('returns false on other error codes (e.g. 500)', () async {
    final client = _FakeHttpClient((_) async {
      return _FakeHttpClientResponse(500);
    });
    final result = await runWithClient(client);
    expect(result, isFalse);
  });

  test('returns false when HttpClient throws', () async {
    final client = _FakeHttpClient((_) => throw Exception('network'));
    final result = await runWithClient(client);
    expect(result, isFalse);
  });
}

// Helpers for faking HttpClient/Response

typedef _RequestHandler = Future<HttpClientResponse> Function(HttpClientRequest);

class _FakeHttpClient extends Fake implements HttpClient {
  final _RequestHandler handler;
  _FakeHttpClient(this.handler);
  @override
  Future<HttpClientRequest> postUrl(Uri url) async {
    return _FakeHttpClientRequest(handler);
  }
}

class _FakeHttpClientRequest extends Fake implements HttpClientRequest {
  final _RequestHandler handler;
  _FakeHttpClientRequest(this.handler);

  @override
  Future<HttpClientResponse> close() => handler(this);

  // Add these required implementations
  @override
  void write(Object? obj) {}

  @override
  void add(List<int> data) {}

  @override
  Future<void> addStream(Stream<List<int>> stream) {
    return stream.drain(); // Already returns a Future
  }
}

class _FakeHttpClientResponse extends Stream<List<int>> implements HttpClientResponse {
  final int _status;
  final Stream<List<int>> _stream;

  _FakeHttpClientResponse(this._status)
      : _stream = Stream<List<int>>.empty();

  @override
  int get statusCode => _status;

  @override
  StreamSubscription<List<int>> listen(void Function(List<int>)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return _stream.listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  Future<dynamic> get done => Future.value();

  @override
  HttpHeaders get headers => _FakeHttpHeaders();

  @override
  X509Certificate? get certificate => null;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  HttpConnectionInfo? get connectionInfo => null;

  @override
  int get contentLength => -1; // -1 means length unknown

  @override
  List<Cookie> get cookies => [];

  @override
  Future<Socket> detachSocket() => Future.value(_FakeSocket());

  @override
  bool get isRedirect => false;

  @override
  bool get persistentConnection => false;

  @override
  String get reasonPhrase => statusCode == 201 ? 'Created' :
  statusCode == 409 ? 'Conflict' : 'Error';

  @override
  Future<HttpClientResponse> redirect([String? method, Uri? url, bool? followLoops]) =>
      Future.value(this);

  @override
  List<RedirectInfo> get redirects => [];
}

// Simple HttpHeaders implementation
class _FakeHttpHeaders implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeSocket extends Fake implements Socket {
  @override
  Future<void> close() => Future.value(); // Changed from void to Future<void>

  @override
  void destroy() {}

  @override
  int get port => 0;

  @override
  InternetAddress get address => InternetAddress.loopbackIPv4;

  @override
  int get remotePort => 0;

  @override
  InternetAddress get remoteAddress => InternetAddress.loopbackIPv4;

  @override
  Future<void> get done => Future.value();

  // Add stream-related methods since Socket is a StreamSink<List<int>>
  @override
  void add(List<int> data) {}

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<List<int>> stream) => Future.value();

  // Socket is also a Stream<Uint8List>
  @override
  StreamSubscription<Uint8List> listen(
      void Function(Uint8List)? onData, {
        Function? onError,
        void Function()? onDone,
        bool? cancelOnError,
      }) {
    return Stream<Uint8List>.empty().listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}