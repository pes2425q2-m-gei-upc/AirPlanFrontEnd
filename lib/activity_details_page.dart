import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:airplan/air_quality.dart';
import 'invite_users_dialog.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ActivityDetailsPage extends StatefulWidget {
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
  State<ActivityDetailsPage> createState() => _ActivityDetailsPageState();
}

class _ActivityDetailsPageState extends State<ActivityDetailsPage> {
  bool showParticipants = false;
  List<String> participants = []; // Aquí se cargan los participantes

  // Simulación de carga de participantes
  Future<void> loadParticipants() async {
    final url = Uri.parse('http://localhost:8080/api/activitats/${widget.id}/participants'); // Asegúrate que el host es accesible

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        setState(() {
          participants = jsonList.map((e) => e.toString()).toList();
          showParticipants = true;
        });
      } else {
        print('Error al obtener participantes: ${response.statusCode}');
      }
    } catch (e) {
      print('Excepción al cargar participantes: $e');
    }
  }


  @override
  Widget build(BuildContext context) {
    final String? currentUser = FirebaseAuth.instance.currentUser?.displayName;
    final bool isCurrentUserCreator = currentUser != null && widget.creator == currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('Activity Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView( // Usamos ListView en lugar de Column para scroll
          children: [
            Text('ID: ${widget.id}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            SizedBox(height: 16),
            Text(widget.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
            SizedBox(height: 16),
            Image.network('https://via.placeholder.com/150'),
            SizedBox(height: 16),
            Text(widget.description, style: TextStyle(fontSize: 16)),
            SizedBox(height: 16),
            Column(
              children: widget.airQualityData.map((data) {
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
            Row(children: [
              Icon(Icons.calendar_today),
              SizedBox(width: 8),
              Text('Start: ${widget.startDate}', style: TextStyle(fontSize: 16)),
            ]),
            SizedBox(height: 8),
            Row(children: [
              Icon(Icons.calendar_today),
              SizedBox(width: 8),
              Text('End: ${widget.endDate}', style: TextStyle(fontSize: 16)),
            ]),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Handle registration request
              },
              child: Text('Request Registration'),
            ),
            SizedBox(height: 16),

            // 🔽 BOTÓN "SHOW PARTICIPANTS"
            ElevatedButton(
              onPressed: () {
                if (!showParticipants) {
                  loadParticipants();
                } else {
                  setState(() {
                    showParticipants = false;
                  });
                }
              },
              child: Text(showParticipants ? 'Hide Participants' : 'Show Participants'),
            ),
            if (showParticipants)
              ...participants.map((p) => ListTile(
                title: Text(p),
                trailing: isCurrentUserCreator
                    ? IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('Eliminar participante'),
                        content: Text('¿Estás seguro de que quieres eliminar a $p de la actividad?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text('No'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text('Sí'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      final url = Uri.parse(
                          'http://10.0.2.2:8080/api/activitats/${widget.id}/participants/$p');

                      try {
                        final response = await http.delete(url);
                        if (response.statusCode == 200) {
                          setState(() {
                            participants.remove(p);
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$p eliminado correctamente')),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error al eliminar $p')),
                          );
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error de red al eliminar $p')),
                        );
                      }
                    }
                  },
                )
                    : null,
              )),

            SizedBox(height: 16),
            Row(children: [
              Icon(Icons.person),
              SizedBox(width: 8),
              Text(widget.creator, style: TextStyle(color: Colors.purple, fontSize: 16)),
            ]),
            SizedBox(height: 16),
            Row(children: [
              Icon(Icons.share),
              SizedBox(width: 8),
              Text('Share', style: TextStyle(fontSize: 16)),
            ]),
            if (isCurrentUserCreator) ...[
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => InviteUsersDialog(activityId: widget.id, creator: widget.creator),
                  );
                },
                child: const Text('Invitar Usuarios'),
              ),
              SizedBox(height: 16),
              ElevatedButton(onPressed: widget.onEdit, child: Text('Edit Activity')),
              SizedBox(height: 16),
              ElevatedButton(onPressed: widget.onDelete, child: Text('Delete Activity')),
            ],
          ],
        ),
      ),
    );
  }

  String traduirContaminant(Contaminant contaminant) {
    switch (contaminant) {
      case Contaminant.so2: return 'SO2';
      case Contaminant.pm10: return 'PM10';
      case Contaminant.pm2_5: return 'PM2.5';
      case Contaminant.no2: return 'NO2';
      case Contaminant.o3: return 'O3';
      case Contaminant.h2s: return 'H2S';
      case Contaminant.co: return 'CO';
      case Contaminant.c6h6: return 'C6H6';
    }
  }

  String traduirAQI(AirQuality aqi) {
    switch (aqi) {
      case AirQuality.excelent: return 'Excelent';
      case AirQuality.bona: return 'Bona';
      case AirQuality.dolenta: return 'Dolenta';
      case AirQuality.pocSaludable: return 'Poc Saludable';
      case AirQuality.moltPocSaludable: return 'Molt Poc Saludable';
      case AirQuality.perillosa: return 'Perillosa';
    }
  }
}
