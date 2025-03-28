import 'package:http/http.dart' as http;

class ApiService {
  final String baseUrl = "http://172.16.4.35:8080";  // La URL de tu backend

  Future<String> fetchData() async {
    final response = await http.get(Uri.parse('$baseUrl/api/data'));

    if (response.statusCode == 200) {
      return response.body;
    } else {
      throw Exception('Failed to load data');
    }
  }
}