import 'package:flutter/material.dart';

class ActivityDetailsPage extends StatelessWidget {
  final String id;
  final String title;
  final String creator;
  final String description;
  final String airQuality;
  final Color airQualityColor;
  final String startDate;
  final String endDate;
  final bool isEditable;

  const ActivityDetailsPage({
    super.key,
    required this.id,
    required this.title,
    required this.creator,
    required this.description,
    required this.airQuality,
    required this.airQualityColor,
    required this.startDate,
    required this.endDate,
    required this.isEditable,
  });

  @override
  Widget build(BuildContext context) {
    print('isEditable: $isEditable'); // Depuración
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
            Row(
              children: [
                Icon(Icons.air),
                SizedBox(width: 8),
                Text(
                  airQuality,
                  style: TextStyle(
                    color: airQualityColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
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
            if (isEditable) ...[
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  // Lógica para editar la actividad
                  _editActivity(context);
                },
                child: Text('Edit Activity'),
              ),
              ElevatedButton(
                onPressed: () {
                  // Lógica para eliminar la actividad
                  _deleteActivity(context);
                },
                child: Text('Delete Activity'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _editActivity(BuildContext context) {
    // Lógica para editar la actividad
    print('Editar actividad: $id');
    // Puedes navegar a una página de edición o mostrar un diálogo de edición
  }

  void _deleteActivity(BuildContext context) {
    // Lógica para eliminar la actividad
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Eliminar actividad'),
          content: Text('¿Estás seguro de que quieres eliminar esta actividad?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Cerrar el diálogo
              },
              child: Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                // Lógica para eliminar la actividad
                print('Actividad eliminada: $id');
                Navigator.pop(context); // Cerrar el diálogo
                Navigator.pop(context); // Volver a la página anterior
              },
              child: Text('Eliminar', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}