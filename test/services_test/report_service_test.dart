import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:http/http.dart' as http;
import 'package:airplan/report_service.dart';
import 'package:airplan/services/api_config.dart';
import 'report_service_test.mocks.dart';

@GenerateMocks([http.Client, ApiConfig])
void main() {
  group('ReportService Tests', () {
    late ReportService reportService;
    late MockClient mockClient;
    late MockApiConfig mockApiConfig;

    setUp(() {
      mockClient = MockClient();
      mockApiConfig = MockApiConfig();
      reportService = ReportService(client: mockClient, apiConfig: mockApiConfig);
    });

    test('fetchReports returns a list of reports on success', () async {
      final mockResponse = jsonEncode([
        {
          'reporterUsername': 'user1',
          'reportedUsername': 'user2',
          'reason': 'spam',
          'timestamp': '2023-10-01T12:00:00Z', // Cambiar 'date' por 'timestamp'
        }
      ]);

      when(mockApiConfig.buildUrl(any)).thenReturn('http://mocked_url/api/report');
      when(mockClient.get(any)).thenAnswer(
            (_) async => http.Response(mockResponse, 200),
      );

      final result = await reportService.fetchReports();

      expect(result, isA<List<Report>>());
      expect(result.first.reportingUser, 'user1');
      expect(result.first.reportedUser, 'user2');
      expect(result.first.reason, 'spam');
    });

    test('fetchReports throws on error response', () async {
      when(mockApiConfig.buildUrl(any)).thenReturn('http://mocked_url/api/report');
      when(mockClient.get(any)).thenAnswer(
            (_) async => http.Response('Not found', 404),
      );

      expect(reportService.fetchReports(), throwsException);
    });

    test('deleteReport sends correct request', () async {
      final report = Report(
          reportingUser: 'user1',
          reportedUser: 'user2',
          reason: 'spam',
          date: DateTime.now()
      );

      when(mockApiConfig.buildUrl(any)).thenReturn('http://mocked_url/api/report');
      when(mockClient.delete(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body')
      )).thenAnswer((_) async => http.Response('', 200));

      await reportService.deleteReport(report);

      verify(mockClient.delete(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body')
      )).called(1);
    });

    test('deleteReport throws on error', () async {
      final report = Report(
          reportingUser: 'user1',
          reportedUser: 'user2',
          reason: 'spam',
          date: DateTime.now()
      );

      when(mockApiConfig.buildUrl(any)).thenReturn('http://mocked_url/api/report');
      when(mockClient.delete(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body')
      )).thenAnswer((_) async => http.Response('Error', 400));

      expect(reportService.deleteReport(report), throwsException);
    });

    test('blockUser sends correct request', () async {
      when(mockApiConfig.buildUrl(any)).thenReturn('http://mocked_url/api/blocks/create');
      when(mockClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body')
      )).thenAnswer((_) async => http.Response('', 201));

      await reportService.blockUser('blocker', 'blocked');

      verify(mockClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body')
      )).called(1);
    });

    test('blockUser throws on error', () async {
      when(mockApiConfig.buildUrl(any)).thenReturn('http://mocked_url/api/blocks/create');
      when(mockClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body')
      )).thenAnswer((_) async => http.Response('Error', 400));

      expect(reportService.blockUser('blocker', 'blocked'), throwsException);
    });
  });
}