import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:http/http.dart' as http;
import 'package:airplan/air_quality.dart';

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
                  onPressed: () {
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
                                itemBuilder: (context, _) => Icon(
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
                                  userId: currentUser!,
                                  rating: rating,
                                  comment: commentController.text,
                                );
                                Navigator.of(context).pop();
                              },
                              child: Text('Submit'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  child: Text('Rate Activity'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void saveRating({
    required String activityId,
    required String userId,
    required double rating,
    String? comment,
  }) async {
    final String backendUrl = 'http://127.0.0.1:8080/valoracions';

    try {
      final response = await http.post(
        Uri.parse(backendUrl),
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

      if (response.statusCode == 200) {
        print('Rating saved successfully: ${response.body}');
      } else {
        print('Failed to save rating: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error connecting to backend: $e');
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
}