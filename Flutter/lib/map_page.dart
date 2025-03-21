import 'dart:convert';
import 'air_quality.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'activity_details_page.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController mapController = MapController();
  LatLng selectedLocation = LatLng(0, 0);
  String placeDetails = "";
  List<CircleMarker> circles = [];
  Map<LatLng, Map<Contaminant, AirQualityData>> contaminantsPerLocation = {};
  LatLng currentPosition = LatLng(41.3851, 2.1734); // Default to Barcelona
  Map<LatLng, String> savedLocations = {};
  bool showAirQuality = true;
  List<Map<String, dynamic>> activities = [];
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
    fetchLocationUpdates();
    fetchAirQualityData();
    _loadActivities();
  }

  Future<void> fetchPlaceDetails(LatLng position) async {
    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          placeDetails = data['display_name'] ?? "No address found";
        });
      } else {
        throw Exception('Failed to load place details');
      }
    } catch (e) {
      setState(() {
        placeDetails = "Error fetching place details";
      });
    }
  }

  Future<void> fetchAirQualityData() async {
    final url = Uri.parse('https://analisi.transparenciacatalunya.cat/resource/tasf-thgu.json?data='+DateTime.now().toString().substring(0,10));

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          circles = createCirclesFromAirQualityData(data);
        });
      } else {
        throw Exception('Failed to load air quality data');
      }
    } catch (e) {
      print("Error fetching air quality data: $e");
    }
  }

  List<CircleMarker> createCirclesFromAirQualityData(dynamic data) {
    for (var entry in data) {
      LatLng position = LatLng(double.parse(entry['latitud']), double.parse(entry['longitud']));
      Contaminant contaminant = Contaminant.SO2;
      try {
        contaminant = parseContaminant(entry['contaminant']);
        AirQualityData aqd = getLastAirQualityData(entry);
        //guarda el valor de la última hora pel contaminant que s'ha mesurat
        if (contaminantsPerLocation[position] == null) {
          Map<Contaminant,AirQualityData> contaminants = {};
          contaminantsPerLocation[position] = contaminants;
        }
        if (contaminantsPerLocation[position]![contaminant] == null || (aqd.lastDateHour.isAfter(contaminantsPerLocation[position]?[contaminant]!.lastDateHour as DateTime))) {
          contaminantsPerLocation[position]?[contaminant] = aqd;
        }
      } catch (e) {
        //TODO informar de que hi ha un contaminant desconegut i no es mostrarà
      }
    }

    List<CircleMarker> circles = [];
    contaminantsPerLocation.forEach((LatLng pos,Map<Contaminant,AirQualityData> contaminants) {
      AirQuality worstAQI = AirQuality.excelent;
      contaminants.forEach((Contaminant key, AirQualityData aqd) {
        if (aqd.aqi.index > worstAQI.index) {
          worstAQI = aqd.aqi;
        }
      });
      Color color = getColorForAirQuality(worstAQI);
      circles.add(CircleMarker(
        point: pos,
        color: color,
        borderStrokeWidth: 2.0,
        borderColor: color,
        radius: 20, // Radius in pixels
      ));
    });

    return circles;
  }

  void _addMarker(LatLng position) async {
    setState(() {
      selectedLocation = position;
    });
    await fetchPlaceDetails(position);
    _showPlaceDetails();
  }

  void _onMapTapped(TapPosition p, LatLng position) {
    _addMarker(position);
  }

  void _toggleAirQuality() {
    setState(() {
      showAirQuality = !showAirQuality;
    });
  }

  void _showPlaceDetails() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.3,
          minChildSize: 0.1,
          maxChildSize: 0.8,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 50,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Selected Location',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 5),
                    Text(placeDetails),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            savedLocations[selectedLocation] = placeDetails;
                            Navigator.pop(context); // Close the modal
                            _showFormWithLocation(selectedLocation);
                          },
                          child: const Text("Crea Activitat"),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              savedLocations[selectedLocation] = placeDetails;
                            });
                            Navigator.pop(context); // Close the modal
                          },
                          child: const Text("Guardar marcador"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showFormWithLocation(LatLng location) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Enter Details'),
          content: FormDialog(
            initialLocation: '${location.latitude},${location.longitude}',
            initialPlaceDetails: placeDetails,
            initialTitle: '',
            initialUser: '',
            initialDescription: '',
            initialStartDate: '',
            initialEndDate: '',
            savedLocations: savedLocations,
          ),
        );
      },
    );

    if (result != null) {
      _sendActivityToBackend(result);
    }
  }

  Future<void> fetchLocationUpdates() async {
    // Simulate fetching current location
    setState(() {
      currentPosition = LatLng(41.3851, 2.1734); // Default to Barcelona
    });
  }

  Future<void> _loadActivities() async {
    try {
      final actividades = await fetchActivities();
      setState(() {
        activities = actividades;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar las actividades: $e')),
      );
    }
  }

  Future<void> _deleteActivityFromBackend(String activityId) async {
    final url = Uri.parse('http://localhost:8080/api/activitats/$activityId'); // URL de tu backend
    try {
      final response = await http.delete(url);
      if (response.statusCode == 200) {
        // Actividad eliminada correctamente en el backend
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Actividad eliminada correctamente')),
        );
      } else {
        // Error al eliminar la actividad
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar la actividad: ${response.body}')),
        );
      }
    } catch (e) {
      // Error de conexión
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de conexión: $e')),
      );
    }
  }

  Future<List<Map<String, dynamic>>> fetchActivities() async {
    final url = Uri.parse('http://localhost:8080/api/activitats'); // Reemplaza con la URL de tu backend
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Error al cargar las actividades');
    }
  }

  Future<void> _sendActivityToBackend(Map<String, String> activityData) async {
    final url = Uri.parse('http://localhost:8080/api/activitats/crear'); // Reemplaza con la URL de tu backend

    // Convertir la ubicación de "x,y" a un objeto JSON
    final ubicacioParts = activityData['location']!.split(',');
    final ubicacio = <String, double>{
      'latitud': double.parse(ubicacioParts[0]), // Usa double.parse
      'longitud': double.parse(ubicacioParts[1]), // Usa double.parse
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
      'ubicacio': ubicacio, // Ahora es un Map<String, double>
      'dataInici': dataInici, // Fecha en formato ISO 8601
      'dataFi': dataFi, // Fecha en formato ISO 8601
      'creador': activityData['user']!,
    };

    try {
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
        setState(() {
          activities = actividades;
        });
      } else {
        // Hubo un error al crear la actividad
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al crear la actividad: ${response.body}')),
        );
      }
    } catch (e) {
      // Error de conexión o otro error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de conexión: $e')),
      );
    }
  }

  Future<void> _updateActivityInBackend(String activityId, Map<String, String> activityData) async {
    final url = Uri.parse('http://localhost:8080/api/activitats/editar/$activityId'); // URL de tu backend

    // Convertir la ubicación de "x,y" a un objeto JSON
    final ubicacioParts = activityData['location']!.split(',');
    final ubicacio = <String, double>{
      'latitud': double.parse(ubicacioParts[0]),
      'longitud': double.parse(ubicacioParts[1]),
    };

    // Formatear las fechas en formato ISO 8601
    final dateFormat = DateFormat("yyyy-MM-dd'T'HH:mm:ss");
    final dataInici = dateFormat.format(DateTime.parse(activityData['startDate']!));
    final dataFi = dateFormat.format(DateTime.parse(activityData['endDate']!));

    // Construir el cuerpo de la solicitud
    final body = <String, dynamic>{
      'id': activityId,
      'nom': activityData['title']!,
      'descripcio': activityData['description']!,
      'ubicacio': ubicacio,
      'dataInici': dataInici,
      'dataFi': dataFi,
      'creador': activityData['user']!,
    };

    try {
      final response = await http.put(
        url,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        // La actividad se actualizó exitosamente en el backend
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Actividad actualizada exitosamente')),
        );
        fetchAndUpdateActivity(activityId);
      } else {
        // Hubo un error al actualizar la actividad
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar la actividad: ${response.body}')),
        );
      }
    } catch (e) {
      // Error de conexión o otro error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de conexión: $e')),
      );
    }
  }
  // Función para obtener una sola actividad desde el backend y actualizar la lista local
  Future<void> fetchAndUpdateActivity(String activityId) async {
    try {
      // Obtener la actividad actualizada desde el backend
      final updatedActivity = await fetchActivityById(activityId);

      // Actualizar la lista local de actividades
      setState(() {
        final index = activities.indexWhere((a) => a['id'].toString() == activityId);
        if (index != -1) {
          activities[index] = updatedActivity; // Reemplazar la actividad antigua con la actualizada
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Actividad actualizada correctamente')),
      );
    } catch (e) {
      // Manejar errores
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar la actividad: $e')),
      );
    }
  }

// Función para obtener una sola actividad desde el backend
  Future<Map<String, dynamic>> fetchActivityById(String activityId) async {
    final url = Uri.parse('http://localhost:8080/api/activitats/$activityId'); // URL de tu backend
    final response = await http.get(url);

    if (response.statusCode == 200) {
      return jsonDecode(response.body); // Devuelve la actividad como un Map
    } else {
      throw Exception('Error al cargar la actividad');
    }
  }

  void _navigateToActivityDetails(Map<String, dynamic> activity) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ActivityDetailsPage(
          id: activity['id'].toString(),
          title: activity['nom'] ?? '',
          creator: activity['creador'] ?? '',
          description: activity['descripcio'] ?? '',
          startDate: activity['dataInici'] ?? '',
          endDate: activity['dataFi'] ?? '',
          airQuality: activity['airQuality'] ?? '',
          airQualityColor: Colors.lightBlue, // Puedes ajustar esto según la calidad del aire
          isEditable: false,
        ),
      ),
    );
  }

  void _editActivity(Map<String, dynamic> activity) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Editar Actividad'),
          content: FormDialog(
            initialLocation: '${activity['ubicacio']['latitud']},${activity['ubicacio']['longitud']}',
            initialPlaceDetails: activity['ubicacio']['display_name'] ?? '',
            initialTitle: activity['nom'] ?? '',
            initialUser: activity['creador'] ?? '',
            initialDescription: activity['descripcio'] ?? '',
            initialStartDate: activity['dataInici'] ?? '',
            initialEndDate: activity['dataFi'] ?? '',
            savedLocations: savedLocations,
          ),
        );
      },
    );

    if (result != null) {
      _updateActivityInBackend(activity['id'].toString(), result);
    }
  }
  void _deleteActivity(Map<String, dynamic> activity) {
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
                // Eliminar la actividad del backend
                _deleteActivityFromBackend(activity['id'].toString());
                // Eliminar la actividad de la lista local
                setState(() {
                  activities.removeWhere((a) => a['id'] == activity['id']);
                });
                Navigator.pop(context); // Cerrar el diálogo
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Actividad eliminada correctamente')),
                );
              },
              child: Text('Eliminar', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _showActivityDetails(Map<String, dynamic> activity) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: GestureDetector(
                  onTap: () {
                    Navigator.pop(context); // Cerrar el BottomSheet
                    _navigateToActivityDetails(activity); // Navegar a los detalles
                  },
                  child: Text(
                    activity['nom'] ?? 'Sin título',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                subtitle: Text(
                  'Creado por: ${activity['creador'] ?? 'Desconocido'}',
                  style: TextStyle(fontSize: 14),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit, color: Colors.blue),
                      onPressed: () {
                        Navigator.pop(context); // Cerrar el BottomSheet
                        _editActivity(activity); // Lógica para editar la actividad
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        Navigator.pop(context); // Cerrar el BottomSheet
                        _deleteActivity(activity); // Lógica para eliminar la actividad
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("OpenStreetMap Example")),
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: currentPosition,
              initialZoom: 15.0,
              onTap: _onMapTapped,
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
              ),
              if (showAirQuality) CircleLayer(circles: circles),
              MarkerLayer(
                markers: [
                  ...savedLocations.keys.map((location) {
                    return Marker(
                      point: location,
                      child: Icon(Icons.location_on, color: Colors.red, size: 40),
                    );
                  }).toList(),
                  ...activities.map((activity) {
                    final ubicacio = activity['ubicacio'] as Map<String, dynamic>;
                    final lat = ubicacio['latitud'] as double;
                    final lon = ubicacio['longitud'] as double;
                    return Marker(
                      point: LatLng(lat, lon),
                      child: GestureDetector(
                        onTap: () => _showActivityDetails(activity), // Mostrar detalles al hacer clic
                        child: Icon(Icons.event, color: Colors.blue, size: 40),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ],
          ),
          Positioned(
            top: 16,
            right: 16,
            child: FloatingActionButton(
              onPressed: _toggleAirQuality,
              child: Icon(showAirQuality ? Icons.visibility_off : Icons.visibility),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (selectedLocation != LatLng(0, 0)) { // Verifica que la ubicación sea válida
            _showFormWithLocation(selectedLocation);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Selecciona una ubicación en el mapa antes de crear una actividad.')),
            );
          }
        },
        child: Icon(Icons.add_location),
      ),
    );
  }
}

class FormDialog extends StatefulWidget {
  final String initialPlaceDetails;
  final String initialTitle;
  final String initialUser;
  final String initialDescription;
  final String initialStartDate;
  final String initialEndDate;
  final Map<LatLng, String> savedLocations;
  final String initialLocation;

  const FormDialog({
    super.key,
    this.initialPlaceDetails = '',
    this.initialTitle = '',
    this.initialUser = '',
    this.initialDescription = '',
    this.initialStartDate = '',
    this.initialEndDate = '',
    required this.savedLocations,
    required this.initialLocation,
  });

  @override
  _FormDialogState createState() => _FormDialogState();
}

class _FormDialogState extends State<FormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _userController = TextEditingController();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();
  LatLng _selectedLocation = LatLng(0, 0);

  @override
  void initState() {
    super.initState();
    _userController.text = widget.initialUser;
    _titleController.text = widget.initialTitle;
    _descriptionController.text = widget.initialDescription;
    _startDateController.text = widget.initialStartDate;
    _endDateController.text = widget.initialEndDate;
    if (widget.savedLocations.isNotEmpty) {
      _selectedLocation = widget.savedLocations.keys.first;
    }
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
          Flexible(
            child: DropdownButtonFormField<LatLng>(
              value: _selectedLocation,
              items: widget.savedLocations.entries.map((entry) {
                String displayText = entry.value.isNotEmpty
                    ? entry.value
                    : '${entry.key.latitude}, ${entry.key.longitude}';
                return DropdownMenuItem<LatLng>(
                  value: entry.key,
                  child: Text(
                      displayText,
                      overflow: TextOverflow.ellipsis
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedLocation = value!;
                });
              },
              decoration: InputDecoration(labelText: 'Selected Location'),
              validator: (value) {
                if (value == null) {
                  return 'Please select a location';
                }
                return null;
              },
            ),
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
                  'location': widget.initialLocation,
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