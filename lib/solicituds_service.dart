// solicituds_service.dart
import 'dart:convert';
import 'package:airplan/services/api_config.dart';
import 'package:http/http.dart' as http;

class SolicitudsService {
  Future<void> sendSolicitud(int activityId, String requester, String host) async {
    final url = Uri.parse(ApiConfig().buildUrl('api/solicituds/$host/$requester/$activityId'));

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
    final url = Uri.parse(ApiConfig().buildUrl('api/solicituds/$username'));

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Error al obtener las solicitudes: ${response.body}');
    }
  }

  Future<bool> jaExisteixSolicitud(int activityId, String requester, String host) async {
    final url = Uri.parse(ApiConfig().buildUrl('api/solicituds/$host/$requester/$activityId'));

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return data['result'] == true; // Devuelve true si "result" es true
    } else {
      throw Exception('Error al verificar la solicitud: ${response.body}');
    }
  }

  Future<void> cancelarSolicitud (int activtyId, String requester) async {
    final url = Uri.parse(ApiConfig().buildUrl('api/solicituds/$requester/$activtyId'));

    final response = await http.delete(url);

    if (response.statusCode != 200) {
      throw Exception('Error al cancelar la solicitud: ${response.body}');
    }
  }

  Future<List<String>> fetchSolicitudesUnio(String activityId) async {
    final int activityIdInt = int.parse(activityId);
    final url = Uri.parse(ApiConfig().buildUrl('api/solicituds/$activityIdInt/solicituds'));
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> solicitudesJson = json.decode(response.body);
        return solicitudesJson
            .map((json) => json['usernameSolicitant'] as String)
            .toList();
      } else {
        throw Exception('Error al obtener solicitudes: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de red: $e');
    }
  }

  Future<void> aceptarSolicitudUnio(String activityId, String username) async {
    final addParticipantUrl = Uri.parse(ApiConfig().buildUrl('api/activitats/$activityId/$username'));
    final deleteRequestUrl = Uri.parse(ApiConfig().buildUrl('api/solicituds/$username/$activityId'));

    try {
      await http.post(addParticipantUrl);
      await http.delete(deleteRequestUrl);
    } catch (e) {
      throw Exception('Error al aceptar la solicitud: $e');
    }
  }

  Future<void> rechazarSolicitudUnio(String activityId, String username) async {
    final url = Uri.parse(ApiConfig().buildUrl('api/solicituds/$username/$activityId'));
    try {
      await http.delete(url);
    } catch (e) {
      throw Exception('Error al rechazar la solicitud: $e');
    }
  }
}