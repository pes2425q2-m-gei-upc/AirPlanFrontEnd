import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:airplan/services/auth_service.dart';
import 'package:airplan/activity_service.dart';
import 'package:airplan/air_quality.dart';
import 'package:airplan/map_service.dart';
import 'package:airplan/services/note_service.dart';
import 'package:airplan/models/nota.dart';
import 'package:easy_localization/easy_localization.dart';

import 'activity_details_page.dart';

class CalendarPage extends StatefulWidget {
  final AuthService authService;
  final ActivityService activityService;

  CalendarPage({
    super.key,
    AuthService? authService,
    ActivityService? activityService,
  }) : authService = authService ?? AuthService(),
       activityService = activityService ?? ActivityService();

  @override
  CalendarPageState createState() => CalendarPageState();
}

class CalendarPageState extends State<CalendarPage> {
  late final ValueNotifier<List<Map<String, dynamic>>> _selectedEvents;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Map<String, dynamic>>> _events = {};
  bool _isLoading = true;
  final MapService mapService = MapService();
  Map<LatLng, Map<Contaminant, AirQualityData>> contaminantsPerLocation = {};
  final NoteService noteService = NoteService();
  Map<DateTime, List<Nota>> _userNotes = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _selectedEvents = ValueNotifier(_getEventsForDay(_selectedDay!));
    _loadActivities();
    fetchAirQualityData();
    _loadUserNotes();
  }

  @override
  void dispose() {
    _selectedEvents.dispose();
    super.dispose();
  }

  Future<void> _loadUserNotes() async {
    try {
      final username = widget.authService.getCurrentUsername();
      if (username == null) return;

      final notes = await noteService.fetchUserNotes(username);

      setState(() {
        // Group notes by day
        _userNotes = {};
        for (var note in notes) {
          final day = DateTime(
            note.fechacreacion.year,
            note.fechacreacion.month,
            note.fechacreacion.day,
          );
          _userNotes[day] = _userNotes[day] ?? [];
          _userNotes[day]!.add(note);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'calendar_error_loading_notes'.tr()}: $e')),
        );
      }
    }
  }

  List<Nota> _getUserNotesForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _userNotes[normalizedDay] ?? [];
  }

  Future<void> _showAddNoteDialog(DateTime day, [Nota? existingNote]) async {
    final TextEditingController noteController = TextEditingController(
      text: existingNote?.comentario,
    );
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final username = widget.authService.getCurrentUsername();
    TimeOfDay selectedTime = TimeOfDay.now();

    if (existingNote != null) {
      final parts = existingNote.horarecordatorio.split(':');
      selectedTime = TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }

    if (username == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('calendar_user_not_identified'.tr())),
      );
      return;
    }

    // Show dialog to collect note content and time, return inputs as result
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: Text(
                    'calendar_note_for_date_prefix'.tr() +
                        DateFormat('dd/MM/yyyy').format(day),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: noteController,
                        decoration: InputDecoration(
                          hintText: 'calendar_note_placeholder'.tr(),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        title: Text(
                          '${'calendar_time_label'.tr()}: ${selectedTime.format(context)}',
                        ),
                        trailing: const Icon(Icons.edit),
                        onTap: () async {
                          final TimeOfDay? picked = await showTimePicker(
                            context: context,
                            initialTime: selectedTime,
                            helpText: 'calendar_time_picker_help_text'.tr(),
                          );
                          if (picked != null && picked != selectedTime) {
                            setState(() {
                              selectedTime = picked;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('cancel'.tr()),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop({
                          'content': noteController.text,
                          'time': selectedTime,
                          'existingNote': existingNote,
                        });
                      },
                      child: Text(
                        existingNote == null
                            ? 'calendar_save_note_button'.tr()
                            : 'calendar_update_note_button'.tr(),
                      ),
                    ),
                  ],
                ),
          ),
    );

    // After dialog closes, perform CRUD operations and update state
    if (result != null) {
      final content = result['content'] as String;
      final time = result['time'] as TimeOfDay;
      final existing = result['existingNote'] as Nota?;
      final timeString =
          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      // Start loading
      setState(() => _isLoading = true);
      try {
        if (content.isEmpty && existing != null && existing.id != null) {
          await noteService.deleteNote(existing.id!);
        } else if (content.isNotEmpty &&
            existing != null &&
            existing.id != null) {
          final updatedNota = Nota(
            id: existing.id,
            username: username,
            fechacreacion: normalizedDay,
            comentario: content,
            horarecordatorio: timeString,
          );
          await noteService.updateNote(existing.id!, updatedNota);
        } else if (content.isNotEmpty) {
          final newNota = Nota(
            username: username,
            fechacreacion: normalizedDay,
            comentario: content,
            horarecordatorio: timeString,
          );
          await noteService.createNote(newNota);
        }
        await _loadUserNotes();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${'calendar_error_processing_note'.tr()}: $e'),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
        if (mounted) {
          _showActivitiesDialog(day); // Refresh the dialog to show changes
        }
      }
    }
  }

  Future<void> _loadActivities() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final username = widget.authService.getCurrentUsername();
      if (username == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('calendar_user_not_logged_in'.tr())),
        );
        return;
      }
      List<Map<String, dynamic>> activities = await widget.activityService
          .fetchUserActivities(username);
      _events = _groupActivitiesByDay(activities);
      _selectedEvents.value = _getEventsForDay(_selectedDay!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${'calendar_error_loading_activities'.tr()}: $e'),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Map<DateTime, List<Map<String, dynamic>>> _groupActivitiesByDay(
    List<Map<String, dynamic>> activities,
  ) {
    Map<DateTime, List<Map<String, dynamic>>> eventsByDay = {};

    for (var activity in activities) {
      // Create a date range for multi-day events
      DateTime startTime = DateTime.parse(activity['dataInici']);
      DateTime endTime = DateTime.parse(activity['dataFi']);

      DateTime current = DateTime(
        startTime.year,
        startTime.month,
        startTime.day,
      );
      final end = DateTime(endTime.year, endTime.month, endTime.day);

      while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
        if (eventsByDay[current] == null) {
          eventsByDay[current] = [];
        }
        eventsByDay[current]!.add(activity);
        current = current.add(const Duration(days: 1));
      }
    }

    return eventsByDay;
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _events[normalizedDay] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    // Calculate more conservative row height based on calendar format
    final screenHeight = MediaQuery.of(context).size.height;
    final availableHeight =
        screenHeight -
        kToolbarHeight -
        MediaQuery.of(context).padding.top -
        MediaQuery.of(context).padding.bottom;

    // Get number of weeks in the current month view
    final DateTime firstDay = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final DateTime lastDay = DateTime(
      _focusedDay.year,
      _focusedDay.month + 1,
      0,
    );
    final int firstWeekday = firstDay.weekday % 7;
    final int daysInMonth = lastDay.day;
    final int weeksInMonth = ((firstWeekday + daysInMonth) / 7).ceil();

    // Increase buffer for larger safety margin
    final int rowsNeeded = weeksInMonth + 1; // +1 for header row
    final double safetyBuffer = 1.0; // Increased buffer

    // Limit maximum height more strictly
    final dynamicRowHeight = (availableHeight / (rowsNeeded + safetyBuffer))
        .clamp(35.0, 70.0);

    return Scaffold(
      appBar: AppBar(
        title: Text('calendar_page_title'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'refresh'.tr(),
            onPressed: () {
              _loadActivities();
              _loadUserNotes();
              fetchAirQualityData();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              // Add scrolling capability as safety
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: availableHeight - 10, // Extra safety margin
                ),
                child: TableCalendar(
                  focusedDay: _focusedDay,
                  firstDay: DateTime(2020, 1, 1),
                  lastDay: DateTime(2030, 12, 31),
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                    _showActivitiesDialog(selectedDay);
                  },
                  calendarFormat: _calendarFormat,
                  onFormatChanged: (format) {
                    setState(() {
                      _calendarFormat = format;
                    });
                  },
                  eventLoader: _getEventsForDay,
                  rowHeight: dynamicRowHeight,
                  daysOfWeekHeight: 20, // Explicit height for days of week
                  daysOfWeekStyle: DaysOfWeekStyle(
                    // Use a custom builder for each day of the week
                    weekdayStyle: const TextStyle(
                      color: Color(0xFF4F4F4F),
                    ), // Default style for weekdays
                    weekendStyle: const TextStyle(
                      color: Color(0xFF6A6A6A),
                    ), // Default style for weekends
                    dowTextFormatter: (date, locale) {
                      // Use EasyLocalization's context.locale to get current app locale
                      return DateFormat.E(
                        context.locale.toString(),
                      ).format(date);
                    },
                  ),
                  headerStyle: HeaderStyle(
                    formatButtonVisible: true,
                    titleCentered: true,
                    formatButtonShowsNext: false,
                    titleTextStyle: const TextStyle(
                      fontSize: 17.0,
                    ), // Default style
                    titleTextFormatter: (date, locale) {
                      // Use EasyLocalization's context.locale to get current app locale
                      // The 'locale' parameter from titleTextFormatter is the device locale, not necessarily app's one.
                      return DateFormat.yMMMM(
                        context.locale.toString(),
                      ).format(date);
                    },
                  ),
                  calendarStyle: const CalendarStyle(
                    isTodayHighlighted: true,
                    markersMaxCount: 0,
                    markerSize: 0,
                    markerMargin: EdgeInsets.zero,
                    markerDecoration: BoxDecoration(color: Colors.transparent),
                    cellMargin: EdgeInsets.all(2), // Reduce cell margin
                  ),
                  calendarBuilders: CalendarBuilders(
                    defaultBuilder: (context, day, focusedDay) {
                      final events = _getEventsForDay(day);
                      return _buildDayCell(day, events, false, false);
                    },
                    selectedBuilder: (context, day, focusedDay) {
                      final events = _getEventsForDay(day);
                      return _buildDayCell(day, events, true, false);
                    },
                    todayBuilder: (context, day, focusedDay) {
                      final events = _getEventsForDay(day);
                      return _buildDayCell(day, events, false, true);
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCell(
    DateTime day,
    List<Map<String, dynamic>> events,
    bool isSelected,
    bool isToday,
  ) {
    final notes = _getUserNotesForDay(day);
    final hasNotes = notes.isNotEmpty;

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        border: Border.all(
          color:
              isSelected
                  ? Colors.blue
                  : isToday
                  ? Colors.blue.shade700
                  : Colors.grey.shade300,
          width:
              isSelected
                  ? 2
                  : isToday
                  ? 1.5
                  : 1,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: ClipRect(
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            // Fixed day number container with consistent height
            Container(
              height: 18,
              alignment: Alignment.center,
              child: Stack(
                children: [
                  // Day number centered
                  Center(
                    child: Text(
                      '${day.day}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            isSelected || isToday
                                ? FontWeight.bold
                                : FontWeight.normal,
                        color: isSelected ? Colors.blue : Colors.black,
                      ),
                    ),
                  ),
                  // Note indicator on the side (doesn't displace number)
                  if (hasNotes)
                    Positioned(
                      right: 2,
                      child: Icon(Icons.note, size: 12, color: Colors.amber),
                    ),
                ],
              ),
            ),
            // Activity indicators
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Your existing activity indicator code
                  final double barHeight = 6.0;
                  final double barMargin = 2.0;
                  final totalBarHeight = barHeight + barMargin;

                  final hasOverflow = events.length > 1;
                  final overflowHeight = hasOverflow ? 12.0 : 0.0;
                  final availableHeight =
                      constraints.maxHeight - overflowHeight;

                  int maxBars = (availableHeight / totalBarHeight).floor();
                  maxBars = maxBars.clamp(0, events.length);

                  if (maxBars <= 0 && events.isNotEmpty) {
                    return Center(
                      child: Text(
                        '${events.length}',
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                    );
                  }

                  return Stack(
                    children: [
                      ...List.generate(maxBars, (index) {
                        if (index >= events.length) {
                          return const SizedBox.shrink();
                        }
                        return Positioned(
                          top: index * totalBarHeight,
                          left: 4,
                          right: 4,
                          height: barHeight,
                          child: Container(
                            decoration: BoxDecoration(
                              color: _getActivityColor(events[index]),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        );
                      }),
                      if (events.length > maxBars && maxBars > 0)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Text(
                              '+${events.length - maxBars}',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Update _showActivitiesDialog to include notes
  void _showActivitiesDialog(DateTime day) {
    final activities = _getEventsForDay(day);
    final notes = _getUserNotesForDay(day);

    // Create a combined list with type identification
    final List<Map<String, dynamic>> combinedItems = [];
    final DateTime now = DateTime.now();
    final DateTime normalizedDay = DateTime(day.year, day.month, day.day);

    // Add notes with type indicator
    for (var note in notes) {
      final noteTimeParts = note.horarecordatorio.split(':');
      final noteDateTime = normalizedDay.add(
        Duration(
          hours: int.parse(noteTimeParts[0]),
          minutes: int.parse(noteTimeParts[1]),
        ),
      );
      combinedItems.add({
        'type': 'note',
        'data': note,
        'dateTime': noteDateTime,
        'isStarted': noteDateTime.isBefore(now),
      });
    }

    // Add activities with type indicator
    for (var activity in activities) {
      final activityDateTime = DateTime.parse(activity['dataInici']);
      combinedItems.add({
        'type': 'activity',
        'data': activity,
        'dateTime': activityDateTime,
        'isStarted': activityDateTime.isBefore(now),
      });
    }

    // Sort: first by whether item has started, then by time
    combinedItems.sort((a, b) {
      // If one has started and the other hasn't, started ones come first
      if (a['isStarted'] != b['isStarted']) {
        return a['isStarted'] ? -1 : 1;
      }
      // Otherwise, sort by time
      return a['dateTime'].compareTo(b['dateTime']);
    });

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'calendar_details_for_date_prefix'.tr() +
                DateFormat('dd/MM/yyyy').format(day),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child:
                _isLoading
                    ? Center(child: CircularProgressIndicator())
                    : combinedItems.isEmpty
                    ? Center(child: Text('calendar_no_items_for_day'.tr()))
                    : ListView.builder(
                      shrinkWrap: true,
                      itemCount: combinedItems.length,
                      itemBuilder: (context, index) {
                        final item = combinedItems[index];
                        if (item['type'] == 'note') {
                          return _buildNoteItem(
                            item['data'] as Nota,
                            day,
                            item['isStarted'] as bool,
                          );
                        } else {
                          return _buildActivityItem(
                            item['data'] as Map<String, dynamic>,
                            item['isStarted'] as bool,
                          );
                        }
                      },
                    ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('calendar_add_note_button'.tr()),
              onPressed: () {
                Navigator.of(context).pop();
                _showAddNoteDialog(day);
              },
            ),
            TextButton(
              child: Text('calendar_close_button'.tr()),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildNoteItem(Nota nota, DateTime day, bool isStarted) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      color: isStarted ? Colors.grey[300] : Colors.white,
      child: ListTile(
        leading: Tooltip(
          message: 'calendar_note_tooltip'.tr(),
          child: Icon(Icons.note, color: Colors.orange),
        ),
        title: Text(
          nota.comentario,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(nota.horarecordatorio),
        onTap: () => _showAddNoteDialog(day, nota), // Allow editing
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          tooltip: 'calendar_delete_note_tooltip'.tr(),
          onPressed: () async {
            // Confirmation dialog before deleting
            final confirmDelete = await showDialog<bool>(
              context: context,
              builder:
                  (context) => AlertDialog(
                    title: Text(
                      'confirm_delete_title'.tr(),
                    ), // Assuming 'confirm_delete_title' exists
                    content: Text(
                      'confirm_delete_message_note'.tr(),
                    ), // Assuming 'confirm_delete_message_note' exists
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text('cancel'.tr()),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: Text('delete'.tr()),
                      ), // Assuming 'delete' key exists
                    ],
                  ),
            );
            if (confirmDelete == true && nota.id != null) {
              setState(() => _isLoading = true);
              try {
                await noteService.deleteNote(nota.id!);
                await _loadUserNotes(); // Refresh notes
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${'calendar_error_processing_note'.tr()}: $e',
                      ),
                    ),
                  );
                }
              } finally {
                if (mounted) {
                  setState(() => _isLoading = false);
                  Navigator.of(
                    context,
                  ).pop(); // Close the current dialog (activities/notes list)
                  _showActivitiesDialog(day); // Reopen with updated data
                }
              }
            }
          },
        ),
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity, bool isStarted) {
    final activityColor = _getActivityColor(activity);
    final startTime = DateTime.parse(activity['dataInici']);
    final formattedTime = DateFormat('HH:mm').format(startTime);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      color: isStarted ? Colors.grey[300] : Colors.white,
      child: ListTile(
        leading: Tooltip(
          message: 'calendar_activity_tooltip'.tr(),
          child: Icon(Icons.event, color: activityColor),
        ),
        title: Text(
          activity['nom'] ?? 'No name',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${activity['tipus']} - $formattedTime',
        ), // Consider localizing 'No name' and 'tipus' if they are static strings
        onTap: () => _navigateToActivityDetails(activity),
      ),
    );
  }

  Color _getActivityColor(Map<String, dynamic> activity) {
    // Create different colors based on activity attributes
    // For example, based on a hash of the activity's ID or name
    int hash = activity['id'].hashCode;
    List<Color> colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
    ];

    return colors[hash.abs() % colors.length];
  }

  void _navigateToActivityDetails(Map<String, dynamic> activity) {
    final ubicacio = activity['ubicacio'] as Map<String, dynamic>;
    final lat = ubicacio['latitud'] as double;
    final lon = ubicacio['longitud'] as double;
    List<AirQualityData> airQualityData = findClosestAirQualityData(
      LatLng(lat, lon),
    ); //tengo lo mismo en valoracion por eso no se hace bien lo del air quality
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ActivityDetailsPage(
              id: activity['id'].toString(),
              title: activity['nom'] ?? '',
              creator: activity['creador'] ?? '',
              description: activity['descripcio'] ?? '',
              startDate: activity['dataInici'] ?? '',
              endDate: activity['dataFi'] ?? '',
              airQualityData: airQualityData,
              isEditable:
                  activity['creador'] ==
                  widget.authService.getCurrentUsername(),
              onEdit: () => {},
              onDelete: () => {},
            ),
      ),
    );
  }

  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null) return 'calendar_date_not_available'.tr();
    try {
      DateTime dateTime = DateTime.parse(dateTimeStr);
      return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
    } catch (e) {
      return 'calendar_date_not_available'.tr();
    }
  }

  Future<void> fetchAirQualityData() async {
    try {
      await mapService.fetchAirQualityData(contaminantsPerLocation);
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${'calendar_error_loading_air_quality'.tr()}: $e'),
          ),
        );
      }
    }
  }

  List<AirQualityData> findClosestAirQualityData(LatLng activityLocation) {
    double closestDistance = double.infinity;
    LatLng closestLocation = LatLng(0, 0);
    List<AirQualityData> listAQD = [];

    contaminantsPerLocation.forEach((location, dataMap) {
      final distance = Distance().as(
        LengthUnit.Meter,
        activityLocation,
        location,
      );
      if (distance < closestDistance) {
        closestDistance = distance;
        closestLocation = location;
      }
    });

    contaminantsPerLocation[closestLocation]?.forEach((
      contaminant,
      airQualityData,
    ) {
      listAQD.add(airQualityData);
    });

    return listAQD;
  }
}
