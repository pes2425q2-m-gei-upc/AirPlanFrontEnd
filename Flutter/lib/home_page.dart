import 'package:flutter/material.dart';
import 'dart:math';
import 'activity_details_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<List<Map<String, String>>> _grid = List.generate(10, (_) => List.generate(10, (_) => {}));
  String _title = '';
  String _creator = '';
  String _description = '';
  String _airQuality = '';
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
        };
      }
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
          'airQuality': _grid[x][y]['airQuality']!,
          'color': _grid[x][y]['color']!,
        };
      });
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
          'airQuality': _grid[x][y]['airQuality']!,
          'color': _grid[x][y]['color']!,
        };
        _showDetails = false;
      });
    }
  }

  void _showActivityDetails() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ActivityDetailsPage(
          title: _title,
          creator: _creator,
          description: _description,
          airQuality: _airQuality,
          airQualityColor: _airQualityColor,
          isEditable: true,
        ),
      ),
    );
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
                                    if (_grid[x][y]['title']!.isNotEmpty) {
                                      setState(() {
                                        _title = _grid[x][y]['title'] ?? '';
                                        _creator = _grid[x][y]['creator'] ?? '';
                                        _description = _grid[x][y]['description'] ?? '';
                                        _airQuality = _grid[x][y]['airQuality'] ?? '';
                                        _airQualityColor = Color(int.parse(_grid[x][y]['color']!));
                                        _showDetails = true;
                                        _selectedX = x;
                                        _selectedY = y;
                                      });
                                    }
                                  },
                                  child: Container(
                                    width: 50,
                                    height: 50,
                                    margin: EdgeInsets.all(1),
                                    color: Color(int.parse(_grid[x][y]['color']!)),
                                    child: Center(
                                      child: _grid[x][y]['title']!.isNotEmpty
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
                      onTap: _showActivityDetails,
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

  const FormDialog({super.key, 
    this.initialLocation = '',
    this.initialTitle = '',
    this.initialUser = '',
    this.initialDescription = '',
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

  @override
  void initState() {
    super.initState();
    _locationController.text = widget.initialLocation;
    _userController.text = widget.initialUser;
    _titleController.text = widget.initialTitle;
    _descriptionController.text = widget.initialDescription;
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
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                Navigator.of(context).pop({
                  'location': _locationController.text,
                  'user': _userController.text,
                  'title': _titleController.text,
                  'description': _descriptionController.text,
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