import 'dart:convert';
import 'package:airplan/services/api_config.dart';
import 'package:airplan/services/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:http/http.dart' as http;
import 'package:airplan/air_quality.dart';

class Valoracio {
  final String username;
  final int idActivitat;
  final double valoracion;
  final String? comentario;
  final DateTime fecha;

  Valoracio({
    required this.username,
    required this.idActivitat,
    required this.valoracion,
    this.comentario,
    required this.fecha,
  });

  factory Valoracio.fromJson(Map<String, dynamic> json) {
    return Valoracio(
      username: json['username'],
      idActivitat: json['idActivitat'],
      valoracion: json['valoracion'].toDouble(),
      comentario: json['comentario'],
      fecha: DateTime.parse(json['fechaValoracion']),
    );
  }
}

class ActivityDetailsPage extends StatelessWidget {
  final String id;
  final String title;
  final String creator;
  final String description;
  final List<AirQualityData> airQualityData;
  final String startDate;
  final String endDate;
  final bool isEditable;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ActivityDetailsPage({
    super.key,
    required this.id,
    required this.title,
    required this.creator,
    required this.description,
    required this.airQualityData,
    required this.startDate,
    required this.endDate,
    required this.isEditable,
    required this.onEdit,
    required this.onDelete,
  });

  Future<List<Valoracio>> fetchValoracions(String activityId) async {
    final backendUrl = Uri.parse(ApiConfig().buildUrl('valoracions/activitat/$activityId'));

    try {
      final response = await http.get(backendUrl);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final List<Valoracio> valoracions = data.map((json) => Valoracio.fromJson(json)).toList();
        // Ordenar de más nuevo a más antiguo
        valoracions.sort((a, b) => b.fecha.compareTo(a.fecha));
        return valoracions;
      } else {
        throw Exception('Failed to load ratings');
      }
    } catch (e) {
      throw Exception('Error connecting to backend: $e');
    }
  }

  // New method to check if a user has already rated an activity
  Future<bool> checkUserHasRated(String activityId, String userId) async {
    final backendUrl = Uri.parse(ApiConfig().buildUrl('valoracions/usuario/$userId/activitat/$activityId'));

    try {
      final response = await http.get(backendUrl);
      return response.statusCode == 200 && jsonDecode(response.body) != null;
    } catch (e) {
      return false;
    }
  }

  Widget buildRatingAverage(List<Valoracio> valoracions) {
    if (valoracions.isEmpty) {
      return Text(
        'No hay valoraciones aún',
        style: TextStyle(fontSize: 16),
      );
    }

    final double average = valoracions
        .map((v) => v.valoracion)
        .reduce((a, b) => a + b) / valoracions.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Valoración media:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        SizedBox(height: 8),
        RatingBarIndicator(
          rating: average,
          itemBuilder: (context, index) => Icon(
            Icons.star,
            color: Colors.amber,
          ),
          itemCount: 5,
          itemSize: 30.0,
          direction: Axis.horizontal,
        ),
        Text(
          '${average.toStringAsFixed(1)} de 5 (${valoracions.length} valoraciones)',
          style: TextStyle(fontSize: 16),
        ),
      ],
    );
  }

  Widget buildValoracionItem(Valoracio valoracio) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  valoracio.username,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '${valoracio.fecha.day}/${valoracio.fecha.month}/${valoracio.fecha.year}',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            RatingBarIndicator(
              rating: valoracio.valoracion,
              itemBuilder: (context, index) => Icon(
                Icons.star,
                color: Colors.amber,
              ),
              itemCount: 5,
              itemSize: 20.0,
              direction: Axis.horizontal,
            ),
            if (valoracio.comentario != null && valoracio.comentario!.isNotEmpty) ...[
              SizedBox(height: 8),
              Text(
                valoracio.comentario!,
                style: TextStyle(fontSize: 14),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void saveRating({
    required String activityId,
    required String userId,
    required double rating,
    String? comment,
    required BuildContext context,
  }) async {
    final backendUrl = Uri.parse(ApiConfig().buildUrl('valoracions'));


    try {
      final response = await http.post(
        backendUrl,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'username': userId,
          'idActivitat': activityId,
          'valoracion': rating,
          'comentario': comment,
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final String message = 'Valoración guardada con éxito';
        if(!context.mounted) return;
        NotificationService.showSuccess(context, message);
      } else {
        final String message = 'Error al guardar la valoración';
        if(!context.mounted) return;
        NotificationService.showError(context, message);
      }
    } catch (e) {
      final String message = 'Error al conectar con el backend';
      if(!context.mounted) return;
      NotificationService.showError(context, message);
    }
  }

  String traduirContaminant(Contaminant contaminant) {
    switch (contaminant) {
      case Contaminant.so2:
        return 'SO2';
      case Contaminant.pm10:
        return 'PM10';
      case Contaminant.pm2_5:
        return 'PM2.5';
      case Contaminant.no2:
        return 'NO2';
      case Contaminant.o3:
        return 'O3';
      case Contaminant.h2s:
        return 'H2S';
      case Contaminant.co:
        return 'CO';
      case Contaminant.c6h6:
        return 'C6H6';
    }
  }

  String traduirAQI(AirQuality aqi) {
    switch (aqi) {
      case AirQuality.excelent:
        return 'Excelent';
      case AirQuality.bona:
        return 'Bona';
      case AirQuality.dolenta:
        return 'Dolenta';
      case AirQuality.pocSaludable:
        return 'Poc Saludable';
      case AirQuality.moltPocSaludable:
        return 'Molt Poc Saludable';
      case AirQuality.perillosa:
        return 'Perillosa';
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? currentUser = FirebaseAuth.instance.currentUser?.displayName;
    final bool isCurrentUserCreator = currentUser != null && creator == currentUser;
    final bool isActivityFinished = DateTime.now().isAfter(DateTime.parse(endDate));

    return Scaffold(
      appBar: AppBar(
        title: Text('Activity Details'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ID: $id',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
              SizedBox(height: 16),
              Image.network('https://via.placeholder.com/150'),
              SizedBox(height: 16),
              Text(
                description,
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 16),
              Column(
                children: airQualityData.map((data) {
                  return Row(
                    children: [
                      Icon(Icons.air),
                      SizedBox(width: 8),
                      Text(
                        '${traduirContaminant(data.contaminant)}: ${traduirAQI(data.aqi)} (${data.value} ${data.units})',
                        style: TextStyle(
                          color: getColorForAirQuality(data.aqi),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.calendar_today),
                  SizedBox(width: 8),
                  Text(
                    'Start: $startDate',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today),
                  SizedBox(width: 8),
                  Text(
                    'End: $endDate',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  // Handle registration request
                },
                child: Text('Request Registration'),
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.person),
                  SizedBox(width: 8),
                  Text(
                    creator,
                    style: TextStyle(
                      color: Colors.purple,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.share),
                  SizedBox(width: 8),
                  Text(
                    'Share',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
              if (isCurrentUserCreator) ...[
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: onEdit,
                  child: Text('Edit Activity'),
                ),
                ElevatedButton(
                  onPressed: onDelete,
                  child: Text('Delete Activity'),
                ),
              ],
              if (isActivityFinished)
                ElevatedButton(
                  onPressed: () async {
                    if (currentUser == null) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Usuario no autenticado')),
                        );
                      }
                      return;
                    }
                    bool hasRated = await checkUserHasRated(id, currentUser);
                    if (hasRated) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('Ya has valorado esta actividad')),
                        );
                      }
                      return;
                    }
                    if (context.mounted) {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          double rating = 0;
                          TextEditingController commentController = TextEditingController();

                          return AlertDialog(
                            title: Text('Rate Activity'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                RatingBar.builder(
                                  initialRating: 0,
                                  minRating: 1,
                                  direction: Axis.horizontal,
                                  allowHalfRating: false,
                                  itemCount: 5,
                                  itemBuilder: (context, _) =>
                                      Icon(
                                        Icons.star,
                                        color: Colors.amber,
                                      ),
                                  onRatingUpdate: (value) {
                                    rating = value;
                                  },
                                ),
                                SizedBox(height: 16),
                                TextField(
                                  controller: commentController,
                                  decoration: InputDecoration(
                                    labelText: 'Optional Comment',
                                    border: OutlineInputBorder(),
                                  ),
                                  maxLines: 3,
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                child: Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  saveRating(
                                    activityId: id,
                                    userId: currentUser,
                                    rating: rating,
                                    comment: commentController.text,
                                    context: context,
                                  );
                                  Navigator.of(context).pop();
                                  Navigator.popUntil(context, (route) =>
                                  route
                                      .isFirst); // Vuelve a la pantalla principal
                                },
                                child: Text('Submit'),
                              ),
                            ],
                          );
                        },
                      );
                    }
                  },
                  child: Text('Rate Activity'),
                ),
              SizedBox(height: 24),
              Text(
                'Valoraciones',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              Divider(),
              FutureBuilder<List<Valoracio>>(
                future: fetchValoracions(id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Text('Error al cargar valoraciones: ${snapshot.error}');
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Column(
                      children: [
                        Text('No hay valoraciones aún'),
                        SizedBox(height: 16),
                      ],
                    );
                  } else {
                    final valoracions = snapshot.data!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        buildRatingAverage(valoracions),
                        SizedBox(height: 16),
                        Text(
                          'Todas las valoraciones:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 8),
                        Column(
                          children: valoracions.map((v) => buildValoracionItem(v)).toList(),
                        ),
                      ],
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}