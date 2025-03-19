import 'package:flutter/material.dart';
import 'dart:convert'; // Para usar jsonEncode
import 'dart:math';
import 'activity_details_page.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http; // Importar el paquete http

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<List<Map<String, dynamic>>> _grid = List.generate(10, (_) => List.generate(10, (_) => {}));
  String _title = '';
  String _creator = '';
  String _description = '';
  String _airQuality = '';
  String _startDate = '';
  String _endDate = '';
  Color _airQualityColor = Colors.lightBlue;
  bool _showDetails = false;
  int _selectedX = -1;
  int _selectedY = -1;

  final List<Map<String, dynamic>> _airQualityOptions = [
    {'label': 'Excel·lent', 'color': Colors.lightBlue},
    {'label': 'Bona', 'color': Colors.green},
    {'label': 'Dolenta', 'color': Colors.yellow},
    {'label': 'Poc saludable', 'color': Colors.red},
    {'label': 'Molt poc saludable', 'color': Colors.purple},
    {'label': 'Perillosa', 'color': Colors.deepPurple.shade900},
  ];

  @override
  void initState() {
    super.initState();
    _assignRandomAirQuality();
    _loadActivities();
  }

  void _assignRandomAirQuality() {
    final random = Random();
    for (int x = 0; x < 10; x++) {
      for (int y = 0; y < 10; y++) {
        final airQuality = _airQualityOptions[random.nextInt(_airQualityOptions.length)];
        _grid[x][y] = {
          'title': '',
          'creator': '',
          'description': '',
          'airQuality': airQuality['label'],
          'color': airQuality['color'].value.toString(),
          'startDate': '',
          'endDate': '',
        };
      }
    }
  }

  Future<void> _loadActivities() async {
    try {
      final actividades = await fetchActivities();
      _updateGridWithActivities(actividades);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar las actividades: $e')),
      );
    }
  }

  void _updateGridWithActivities(List<Map<String, dynamic>> actividades) {
    setState(() {
      // No reiniciar la cuadrícula, solo actualizar las celdas necesarias
      for (final actividad in actividades) {
        final ubicacio = actividad['ubicacio'] as Map<String, dynamic>;
        final x = ubicacio['latitud'] as int;
        final y = ubicacio['longitud'] as int;

        _grid[x][y] = {
          'id': actividad['id'],
          'title': actividad['nom'],
          'creator': actividad['creador'],
          'description': actividad['descripcio'],
          'startDate': actividad['dataInici'],
          'endDate': actividad['dataFi'],
          'airQuality': _grid[x][y]['airQuality'],
          'color': _grid[x][y]['color'] ?? Colors.lightBlue.value.toString(),
        };
      }
    });
  }

  Future<List<Map<String, dynamic>>> fetchActivities() async {
    final url = Uri.parse('http://localhost:8080/api/activitats'); // Reemplaza con la URL de tu backend
    final response = await http.get(url);

    if (response.statusCode == 200) {
      // Decodificar el JSON y devolver la lista de actividades
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Error al cargar las actividades');
    }
  }

  void _showForm({int? x, int? y, bool isEdit = false}) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(isEdit ? 'Edit Details' : 'Enter Details'),
          content: FormDialog(
            initialLocation: x != null && y != null ? '$x,$y' : '',
            initialTitle: x != null && y != null ? _grid[x][y]['title'] ?? '' : '',
            initialUser: x != null && y != null ? _grid[x][y]['creator'] ?? '' : '',
            initialDescription: x != null && y != null ? _grid[x][y]['description'] ?? '' : '',
            initialStartDate: x != null && y != null ? _grid[x][y]['startDate'] ?? '' : '',
            initialEndDate: x != null && y != null ? _grid[x][y]['endDate'] ?? '' : '',
          ),
        );
      },
    );

    if (result != null) {
      setState(() {
        int x = int.parse(result['location']!.split(',')[0]);
        int y = int.parse(result['location']!.split(',')[1]);
        _grid[x][y] = {
          'title': result['title']!,
          'creator': result['user']!,
          'description': result['description']!,
          'airQuality': _grid[x][y]['airQuality'] ?? 'Excel·lent',
          'color': _grid[x][y]['color'] ?? Colors.lightBlue.value.toString(),
          'startDate': result['startDate']!,
          'endDate': result['endDate']!,
        };
      });

      // Enviar la solicitud POST al backend
      _sendActivityToBackend(result);
    }
  }

  Future<void> _sendActivityToBackend(Map<String, String> activityData) async {
    final url = Uri.parse('http://localhost:8080/api/activitats/crear'); // Reemplaza con la URL de tu backend

    // Convertir la ubicación de "x,y" a un objeto JSON
    final ubicacioParts = activityData['location']!.split(',');
    final ubicacio = <String, int>{
      'latitud': int.parse(ubicacioParts[0]), // Convertir a int
      'longitud': int.parse(ubicacioParts[1]), // Convertir a int
    };

    // Formatear las fechas en formato ISO 8601
    final dateFormat = DateFormat("yyyy-MM-dd'T'HH:mm:ss");
    final dataInici = dateFormat.format(DateTime.parse(activityData['startDate']!));
    final dataFi = dateFormat.format(DateTime.parse(activityData['endDate']!));

    // Construir el cuerpo de la solicitud
    final body = <String, dynamic>{
      'id': '1', // Puedes generar un ID único o dejar que el backend lo genere
      'nom': activityData['title']!,
      'descripcio': activityData['description']!,
      'ubicacio': ubicacio, // Ahora es un Map<String, int>
      'dataInici': dataInici, // Fecha en formato ISO 8601
      'dataFi': dataFi, // Fecha en formato ISO 8601
      'creador': activityData['user']!,
    };

    final response = await http.post(
      url,
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(body), // Codificar el mapa a JSON
    );

    if (response.statusCode == 201) {
      // La actividad se creó exitosamente en el backend
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Actividad creada exitosamente')),
      );

      // Obtener la lista actualizada de actividades
      final actividades = await fetchActivities();
      _updateGridWithActivities(actividades);
    } else {
      // Hubo un error al crear la actividad
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al crear la actividad: ${response.body}')),
      );
    }
  }

  void _deleteLocation(int x, int y) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Deletion'),
          content: Text('Are you sure you want to delete this activity?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      setState(() {
        _grid[x][y] = {
          'title': '',
          'creator': '',
          'description': '',
          'airQuality': _grid[x][y]['airQuality'] ?? 'Excel·lent',
          'color': _grid[x][y]['color'] ?? Colors.lightBlue.value.toString(),
          'startDate': '',
          'endDate': '',
        };
        _showDetails = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue, width: 2),
                  ),
                  child: Stack(
                    children: [
                      InteractiveViewer(
                        constrained: false,
                        minScale: 0.5,
                        maxScale: 2.0,
                        child: Column(
                          children: List.generate(10, (y) {
                            return Row(
                              children: List.generate(10, (x) {
                                return GestureDetector(
                                  onTap: () {
                                    if (_grid[x][y]['title'] != null && _grid[x][y]['title']!.isNotEmpty) {
                                      setState(() {
                                        _title = _grid[x][y]['title'] ?? '';
                                        _creator = _grid[x][y]['creator'] ?? '';
                                        _description = _grid[x][y]['description'] ?? '';
                                        _airQuality = _grid[x][y]['airQuality'] ?? '';
                                        _airQualityColor = Color(int.parse(_grid[x][y]['color']!));
                                        _startDate = _grid[x][y]['startDate'] ?? '';
                                        _endDate = _grid[x][y]['endDate'] ?? '';
                                        _showDetails = true;
                                        _selectedX = x;
                                        _selectedY = y;
                                      });

                                      // Navegar a la página de detalles de la actividad
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ActivityDetailsPage(
                                            id: _grid[x][y]['id'], // Pasar el ID de la actividad
                                            title: _grid[x][y]['title'] ?? '',
                                            creator: _grid[x][y]['creator'] ?? '',
                                            description: _grid[x][y]['description'] ?? '',
                                            startDate: _grid[x][y]['startDate'] ?? '',
                                            endDate: _grid[x][y]['endDate'] ?? '',
                                            airQuality: _grid[x][y]['airQuality'] ?? '',
                                            airQualityColor: Color(int.parse(_grid[x][y]['color']!)),
                                            isEditable: false,
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  child: Container(
                                    width: 50,
                                    height: 50,
                                    margin: EdgeInsets.all(1),
                                    color: Color(int.parse(_grid[x][y]['color']!)),
                                    child: Center(
                                      child: _grid[x][y]['title'] != null && _grid[x][y]['title']!.isNotEmpty
                                          ? Icon(Icons.location_on, color: Colors.red)
                                          : null,
                                    ),
                                  ),
                                );
                              }),
                            );
                          }),
                        ),
                      ),
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: GestureDetector(
                          onTap: _showForm,
                          child: CustomPaint(
                            size: Size(50, 50),
                            painter: SphereWithCrossPainter(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: _airQualityOptions.map((option) {
                  return _buildAirQualityLabel(option['label'], option['color']);
                }).toList(),
              ),
            ),
            if (_showDetails)
              Container(
                color: Colors.lightBlue[100],
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ActivityDetailsPage(
                              id: _grid[_selectedX][_selectedY]['id'],
                              title: _title,
                              creator: _creator,
                              description: _description,
                              startDate: _startDate,
                              endDate: _endDate,
                              airQuality: _airQuality,
                              airQualityColor: _airQualityColor,
                              isEditable: true,
                            ),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          Icon(Icons.event),
                          SizedBox(width: 8),
                          Text(
                            _title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          Spacer(),
                          IconButton(
                            icon: Icon(Icons.edit),
                            onPressed: () => _showForm(x: _selectedX, y: _selectedY, isEdit: true),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete),
                            onPressed: () => _deleteLocation(_selectedX, _selectedY),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Icon(Icons.person),
                        SizedBox(width: 8),
                        Text(
                          _creator,
                          style: TextStyle(
                            color: Colors.purple,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAirQualityLabel(String text, Color color) {
    return Text(
      text,
      style: TextStyle(color: color, fontWeight: FontWeight.bold),
    );
  }
}

class SphereWithCrossPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    // Draw the sphere
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width / 2, paint);

    final crossPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4.0;

    // Draw the vertical line of the cross
    canvas.drawLine(
      Offset(size.width / 2, size.height / 4),
      Offset(size.width / 2, 3 * size.height / 4),
      crossPaint,
    );

    // Draw the horizontal line of the cross
    canvas.drawLine(
      Offset(size.width / 4, size.height / 2),
      Offset(3 * size.width / 4, size.height / 2),
      crossPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class FormDialog extends StatefulWidget {
  final String initialLocation;
  final String initialTitle;
  final String initialUser;
  final String initialDescription;
  final String initialStartDate;
  final String initialEndDate;

  const FormDialog({super.key,
    this.initialLocation = '',
    this.initialTitle = '',
    this.initialUser = '',
    this.initialDescription = '',
    this.initialStartDate = '',
    this.initialEndDate = '',
  });

  @override
  _FormDialogState createState() => _FormDialogState();
}

class _FormDialogState extends State<FormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _locationController = TextEditingController();
  final _userController = TextEditingController();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _locationController.text = widget.initialLocation;
    _userController.text = widget.initialUser;
    _titleController.text = widget.initialTitle;
    _descriptionController.text = widget.initialDescription;
    _startDateController.text = widget.initialStartDate;
    _endDateController.text = widget.initialEndDate;
  }

  Future<void> _selectDateTime(TextEditingController controller) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (pickedDate != null) {
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (pickedTime != null) {
        final DateTime fullDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
        controller.text = DateFormat('yyyy-MM-dd HH:mm').format(fullDateTime);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _locationController,
            decoration: InputDecoration(labelText: 'Location (x,y)'),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a location';
              }
              return null;
            },
          ),
          TextFormField(
            controller: _userController,
            decoration: InputDecoration(labelText: 'User'),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a user';
              }
              return null;
            },
          ),
          TextFormField(
            controller: _titleController,
            decoration: InputDecoration(labelText: 'Title'),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a title';
              }
              return null;
            },
          ),
          TextFormField(
            controller: _descriptionController,
            decoration: InputDecoration(labelText: 'Description'),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a description';
              }
              return null;
            },
          ),
          TextFormField(
            controller: _startDateController,
            decoration: InputDecoration(
              labelText: 'Start Date and Time',
              suffixIcon: IconButton(
                icon: Icon(Icons.calendar_today),
                onPressed: () => _selectDateTime(_startDateController),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a start date and time';
              }
              return null;
            },
          ),
          TextFormField(
            controller: _endDateController,
            decoration: InputDecoration(
              labelText: 'End Date and Time',
              suffixIcon: IconButton(
                icon: Icon(Icons.calendar_today),
                onPressed: () => _selectDateTime(_endDateController),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter an end date and time';
              }
              return null;
            },
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                Navigator.of(context).pop({
                  'location': _locationController.text,
                  'user': _userController.text,
                  'title': _titleController.text,
                  'description': _descriptionController.text,
                  'startDate': _startDateController.text,
                  'endDate': _endDateController.text,
                });
              }
            },
            child: Text('Submit'),
          ),
        ],
      ),
    );
  }
}