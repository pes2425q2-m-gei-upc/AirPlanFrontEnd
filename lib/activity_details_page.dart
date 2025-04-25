import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:airplan/air_quality.dart';
import 'package:airplan/chat_detail_page.dart';

class ActivityDetailsPage extends StatelessWidget {
  final String id;
  final String title;
  final String creator;
  final String description;
  final List<AirQualityData> airQualityData;
  final String startDate;
  final String endDate;
  final bool isEditable;
  final VoidCallback onEdit; // Función para editar
  final VoidCallback onDelete; // Función para eliminar

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
    required this.onEdit, // Añadimos el parámetro onEdit
    required this.onDelete, // Añadimos el parámetro onDelete
  });

  @override
  Widget build(BuildContext context) {
    final String? currentUser = FirebaseAuth.instance.currentUser?.displayName;
    final bool isCurrentUserCreator =
        currentUser != null && creator == currentUser;

    // Don't show message button if the user is the creator
    final bool canSendMessage = !isCurrentUserCreator && currentUser != null;

    return Scaffold(
      appBar: AppBar(title: Text('Activity Details')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ID: $id',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
            ),
            SizedBox(height: 16),
            Image.network('https://via.placeholder.com/150'),
            SizedBox(height: 16),
            Text(description, style: TextStyle(fontSize: 16)),
            SizedBox(height: 16),
            Column(
              children:
                  airQualityData.map((data) {
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
                Text('Start: $startDate', style: TextStyle(fontSize: 16)),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today),
                SizedBox(width: 8),
                Text('End: $endDate', style: TextStyle(fontSize: 16)),
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.person),
                    SizedBox(width: 8),
                    Text(
                      creator,
                      style: TextStyle(color: Colors.purple, fontSize: 16),
                    ),
                  ],
                ),
                if (canSendMessage)
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => ChatDetailPage(username: creator),
                        ),
                      );
                    },
                    icon: Icon(Icons.message),
                    label: Text('Enviar mensaje'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.share),
                SizedBox(width: 8),
                Text('Share', style: TextStyle(fontSize: 16)),
              ],
            ),
            if (isCurrentUserCreator) ...[
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: onEdit, // Usamos la función onEdit
                    child: Text('Edit Activity'),
                  ),
                  ElevatedButton(
                    onPressed: onDelete, // Usamos la función onDelete
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: Text('Delete Activity'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
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
