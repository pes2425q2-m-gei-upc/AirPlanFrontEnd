// solicituds_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class SolicitudsService {
  Future<void> sendSolicitud(int activityId, String requester, String host) async {
    //final url = Uri.parse('http://nattech.fib.upc.edu:40350/api/solicituds/$host/$requester/$activityId');
    final url = Uri.parse('http://127.0.0.1:8080/api/solicituds/$host/$requester/$activityId');

    final response = await http.post(
      url,
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
    );

    if (response.statusCode != 201) {
      throw Exception('Error al enviar la solicitud: ${response.body}');
    }
  }

  Future<List<Map<String, dynamic>>> fetchUserRequests(String username) async {
    //final url = Uri.parse('http://nattech.fib.upc.edu:40350/api/solicituds/$username');
    final url = Uri.parse('http://127.0.0.1:8080/api/solicituds/$username');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Error al obtener las solicitudes: ${response.body}');
    }
  }

  Future<bool> jaExisteixSolicitud(int activityId, String requester, String host) async {
    //final url = Uri.parse('http://nattech.fib.upc.edu:40350/api/solicituds/$host/$requester/$activityId');
    final url = Uri.parse('http://127.0.0.1:8080/api/solicituds/$host/$requester/$activityId');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return data['result'] == true; // Devuelve true si "result" es true
    } else {
      throw Exception('Error al verificar la solicitud: ${response.body}');
    }
  }

  Future<void> cancelarSolicitud (int activtyId, String requester) async {
    //final url = Uri.parse('http://nattech.fib.upc.edu:40350/api/solicituds/$requester/$activtyId');
    final url = Uri.parse('http://127.0.0.1:8080/api/solicituds/$requester/$activtyId');

    final response = await http.delete(url);

    if (response.statusCode != 200) {
      throw Exception('Error al cancelar la solicitud: ${response.body}');
    }
  }
}