import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:airplan/air_quality.dart';
import 'package:airplan/solicituds_service.dart';

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
  _ActivityDetailsPageState createState() => _ActivityDetailsPageState();
}

class _ActivityDetailsPageState extends State<ActivityDetailsPage> {
  late Future<bool> _solicitudExistente;

  @override
  void initState() {
    super.initState();
    _solicitudExistente = _checkSolicitudExistente();
  }

  Future<bool> _checkSolicitudExistente() async {
    final String? currentUser = FirebaseAuth.instance.currentUser?.displayName;
    if (currentUser == null) return false;
    return await SolicitudsService().jaExisteixSolicitud(
      int.parse(widget.id),
      currentUser,
      widget.creator,
    );
  }

  Future<void> _handleSolicitudAction(bool solicitudExistente) async {
    final String? currentUser = FirebaseAuth.instance.currentUser?.displayName;
    if (currentUser == null) return;

    if (solicitudExistente) {
      // Cancelar solicitud
      await SolicitudsService().cancelarSolicitud(int.parse(widget.id), currentUser);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud cancelada correctamente.')),
      );
    } else {
      // Enviar solicitud
      await SolicitudsService().sendSolicitud(
        int.parse(widget.id),
        currentUser,
        widget.creator,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud enviada correctamente.')),
      );
    }

    // Refresh the button state
    setState(() {
      _solicitudExistente = _checkSolicitudExistente();
    });
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ID: ${widget.id}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
            const SizedBox(height: 16),
            Image.network('https://via.placeholder.com/150'),
            const SizedBox(height: 16),
            Text(
              widget.description,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Column(
              children: widget.airQualityData.map((data) {
                return Row(
                  children: [
                    const Icon(Icons.air),
                    const SizedBox(width: 8),
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
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.calendar_today),
                const SizedBox(width: 8),
                Text(
                  'Start: ${widget.startDate}',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today),
                const SizedBox(width: 8),
                Text(
                  'End: ${widget.endDate}',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.person),
                const SizedBox(width: 8),
                Text(
                  widget.creator,
                  style: const TextStyle(
                    color: Colors.purple,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (!isCurrentUserCreator)
              FutureBuilder<bool>(
                future: _solicitudExistente,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  } else if (snapshot.hasError) {
                    return const Text('Error al cargar el estado de la solicitud.');
                  }

                  final solicitudExistente = snapshot.data ?? false;
                  return ElevatedButton(
                    onPressed: () => _handleSolicitudAction(solicitudExistente),
                    child: Text(solicitudExistente ? 'Cancelar solicitud' : 'Solicitar unirse'),
                  );
                },
              ),
            if (isCurrentUserCreator) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: widget.onEdit,
                child: const Text('Edit Activity'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: widget.onDelete,
                child: const Text('Delete Activity'),
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