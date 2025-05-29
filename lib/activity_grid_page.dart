/*import 'package:flutter/material.dart';
import 'dart:math';
import 'activity_details_page.dart';
import 'form_dialog.dart';
import 'package:easy_localization/easy_localization.dart'; // Import easy_localization

class ActivityGridPage extends StatefulWidget {
  const ActivityGridPage({super.key});

  @override
  _ActivityGridPageState createState() => _ActivityGridPageState();
}

class _ActivityGridPageState extends State<ActivityGridPage> {
  final List<List<Map<String, String>>> _grid = List.generate(10, (_) => List.generate(10, (_) => {}));
  String _title = '';
  String _creator = '';
  String _description = '';
  String _airQuality = '';
  Color _airQualityColor = Colors.lightBlue;
  bool _showDetails = false;
  int _selectedX = -1;
  int _selectedY = -1;

  // Updated to use translation keys if these are displayed in UI, otherwise keep as is.
  // For this example, assuming 'label' is used in UI and needs translation.
  late final List<Map<String, dynamic>> _airQualityOptions;

  @override
  void initState() {
    super.initState();
    // Initialize _airQualityOptions here where context is available or pass translations
    _airQualityOptions = [
      {'label': 'aqi_excellent'.tr(), 'color': Colors.lightBlue},
      {'label': 'aqi_good'.tr(), 'color': Colors.green},
      {'label': 'aqi_poor'.tr(), 'color': Colors.yellow},
      {'label': 'aqi_unhealthy_sensitive'.tr(), 'color': Colors.red}, // Or 'aqi_unhealthy'
      {'label': 'aqi_very_unhealthy'.tr(), 'color': Colors.purple},
      {'label': 'aqi_hazardous'.tr(), 'color': Colors.deepPurple.shade900},
    ];
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
          title: Text(isEdit ? 'edit_details_title'.tr() : 'enter_details_title'.tr()),
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
          title: Text('confirm_deletion_title'.tr()),
          content: Text('confirm_delete_activity_message'.tr()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('cancel_button'.tr()),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('delete_button'.tr()),
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
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
*/
