// report_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:easy_localization/easy_localization.dart';
import 'services/api_config.dart';

class ReportService {
  final http.Client client;
  final ApiConfig apiConfig;

  ReportService({
    http.Client? client,
    ApiConfig? apiConfig,
  })  : client = client ?? http.Client(),
        apiConfig = apiConfig ?? ApiConfig();

  Future<List<Report>> fetchReports() async {
    final url = Uri.parse(apiConfig.buildUrl('api/report'));
    // Usar client en lugar de http.get
    final response = await client.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((json) => Report.fromJson(json)).toList();
    } else {
      throw Exception('error_loading_reports'.tr());
    }
  }

  Future<void> deleteReport(Report report) async {
    final url = Uri.parse(apiConfig.buildUrl('api/report'));
    final body = jsonEncode({
      'reporterUsername': report.reportingUser,
      'reportedUsername': report.reportedUser,
      'reason': report.reason,
    });

    // Usar client en lugar de http.delete
    final response = await client.delete(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception('error_deleting_report'.tr());
    }
  }

  Future<void> blockUser(String blockerUsername, String blockedUsername) async {
    final url = Uri.parse(apiConfig.buildUrl('api/blocks/create'));
    final body = jsonEncode({
      'blockerUsername': blockerUsername,
      'blockedUsername': blockedUsername,
    });

    // Usar client en lugar de http.post
    final response = await client.post(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
      body: body,
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('error_blocking_user'.tr());
    }
  }
}

class Report {
  final String reportedUser;
  final String reportingUser;
  final String reason;
  final DateTime date;

  Report({
    required this.reportedUser,
    required this.reportingUser,
    required this.reason,
    required this.date,
  });

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      reportedUser: json['reportedUsername'],
      reportingUser: json['reporterUsername'],
      reason: json['reason'],
      date: DateTime.parse(json['timestamp']),
    );
  }
}