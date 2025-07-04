import 'package:airplan/services/google_calendar_service.dart';
import 'package:airplan/services/sync_preferences_service.dart';
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
  final GoogleCalendarService _googleCalendarService = GoogleCalendarService();
  final SyncPreferencesService _syncPreferencesService =
      SyncPreferencesService();
  bool _isSyncEnabled = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _selectedEvents = ValueNotifier(_getEventsForDay(_selectedDay!));
    _loadActivities();
    fetchAirQualityData();
    _loadUserNotes();
    _loadSyncPreference();
  }

  @override
  void dispose() {
    _selectedEvents.dispose();
    super.dispose();
  }

  Future<void> _loadSyncPreference() async {
    try {
      final isSyncEnabled = await _syncPreferencesService.isSyncEnabled();
      setState(() {
        _isSyncEnabled = isSyncEnabled;
      });
    } catch (e) {
      debugPrint('Error al cargar preferencia de sincronización: $e');
    }
  }

  Future<void> _toggleSync() async {
    try {
      final bool newSyncState = !_isSyncEnabled;

      if (!newSyncState) {
        // Si estamos desactivando la sincronización, eliminar todos los eventos
        await _googleCalendarService.deleteAllEvents();
      }

      await _syncPreferencesService.setSyncEnabled(newSyncState);

      setState(() {
        _isSyncEnabled = newSyncState;
      });

      // Solo sincronizar si estamos activando la sincronización
      if (_isSyncEnabled) {
        final username = widget.authService.getCurrentUsername();
        if (username != null) {
          // Sincronizar notas existentes
          await noteService.syncAllNotes(username);

          // Sincronizar actividades existentes
          final activities = await widget.activityService.fetchUserActivities(
            username,
          );
          for (var activity in activities) {
            await widget.activityService.syncActivityWithGoogleCalendar(
              activity,
            );
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isSyncEnabled
                  ? 'Sincronización con Google Calendar activada'
                  : 'Sincronización con Google Calendar desactivada',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cambiar la sincronización: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
          SnackBar(
            content: Text(
              'calendar_error_loading_notes'.tr(args: [e.toString()]),
            ),
          ),
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
                    'calendar_note_for_date'.tr(
                      args: [DateFormat('dd/MM/yyyy').format(day)],
                    ),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: noteController,
                        decoration: InputDecoration(
                          labelText: 'calendar_personal_note'.tr(),
                          hintText: 'calendar_write_personal_note'.tr(),
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 5,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text('calendar_reminder_time'.tr()),
                          TextButton(
                            onPressed: () async {
                              final TimeOfDay? time = await showTimePicker(
                                context: context,
                                initialTime: selectedTime,
                              );
                              if (time != null) {
                                setState(() {
                                  selectedTime = time;
                                });
                              }
                            },
                            child: Text(
                              '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('cancel'.tr()),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        // Return collected data to outer function
                        Navigator.of(context).pop({
                          'content': noteController.text.trim(),
                          'time': selectedTime,
                          'existingNote': existingNote,
                        });
                      },
                      child: Text('save'.tr()),
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
            horarecordatorio: timeString,
            comentario: content,
          );
          await noteService.updateNote(existing.id!, updatedNota);
        } else if (content.isNotEmpty) {
          final newNota = Nota(
            username: username,
            fechacreacion: normalizedDay,
            horarecordatorio: timeString,
            comentario: content,
          );
          await noteService.createNote(newNota);
        }
        await _loadUserNotes();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'calendar_error_processing_note'.tr(args: [e.toString()]),
              ),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
        if (mounted) _showActivitiesDialog(day);
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('user_not_found_text'.tr())));
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
            content: Text(
              'calendar_error_loading_activities'.tr(args: [e.toString()]),
            ),
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
        title: Text('calendar_activity_calendar'.tr()),
        actions: [
          IconButton(
            icon: Icon(_isSyncEnabled ? Icons.sync : Icons.sync_disabled),
            onPressed: _toggleSync,
            tooltip:
                _isSyncEnabled
                    ? 'Desactivar sincronización con Google Calendar'.tr()
                    : 'Activar sincronización con Google Calendar'.tr(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadActivities,
            tooltip: 'refresh'.tr(),
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      // Add scrolling capability as safety
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight:
                              availableHeight - 10, // Extra safety margin
                        ),
                        child: TableCalendar(
                          locale:
                              Localizations.localeOf(
                                context,
                              ).toString(), // Use user's language format
                          focusedDay: _focusedDay,
                          firstDay: DateTime(2020, 1, 1),
                          lastDay: DateTime(2030, 12, 31),
                          selectedDayPredicate:
                              (day) => isSameDay(_selectedDay, day),
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
                          daysOfWeekHeight:
                              20, // Explicit height for days of week
                          headerStyle: HeaderStyle(
                            formatButtonVisible: true,
                            titleCentered: true,
                            formatButtonShowsNext: false,
                            formatButtonTextStyle: const TextStyle(),
                            formatButtonDecoration: const BoxDecoration(),
                          ),
                          formatAnimationCurve: Curves.easeInOut,
                          formatAnimationDuration: const Duration(
                            milliseconds: 200,
                          ),
                          availableCalendarFormats: {
                            CalendarFormat.month: 'calendar_format_month'.tr(),
                            CalendarFormat.twoWeeks:
                                'calendar_format_2weeks'.tr(),
                            CalendarFormat.week: 'calendar_format_week'.tr(),
                          },
                          calendarStyle: const CalendarStyle(
                            isTodayHighlighted: true,
                            markersMaxCount: 0,
                            markerSize: 0,
                            markerMargin: EdgeInsets.zero,
                            markerDecoration: BoxDecoration(
                              color: Colors.transparent,
                            ),
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
      final timeParts = note.horarecordatorio.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      final noteDateTime = DateTime(
        normalizedDay.year,
        normalizedDay.month,
        normalizedDay.day,
        hour,
        minute,
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
      final startTime = DateTime.parse(activity['dataInici']);

      combinedItems.add({
        'type': 'activity',
        'data': activity,
        'dateTime': startTime,
        'isStarted': startTime.isBefore(now),
      });
    }

    // Sort: first by whether item has started, then by time
    combinedItems.sort((a, b) {
      if (a['isStarted'] && !b['isStarted']) return 1;
      if (!a['isStarted'] && b['isStarted']) return -1;
      return a['dateTime'].compareTo(b['dateTime']);
    });

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    'calendar_day_date'.tr(
                      args: [DateFormat('dd/MM/yyyy').format(day)],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  iconSize: 20,
                ),
              ],
            ),
            titlePadding: const EdgeInsets.only(
              left: 24,
              top: 24,
              right: 16,
              bottom: 0,
            ),
            content: SizedBox(
              width: double.maxFinite,
              height:
                  MediaQuery.of(context).size.height *
                  0.6, // Use a fixed height proportion
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (combinedItems.isEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: 20, bottom: 20),
                      child: Text('calendar_no_notes_activities'.tr()),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: combinedItems.length,
                        itemBuilder: (context, index) {
                          final item = combinedItems[index];
                          if (item['type'] == 'note') {
                            return _buildNoteItem(
                              item['data'],
                              day,
                              item['isStarted'],
                            );
                          } else {
                            return _buildActivityItem(
                              item['data'],
                              item['isStarted'],
                            );
                          }
                        },
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              // Add note button now positioned in the actions section
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showAddNoteDialog(day);
                  },
                  icon: const Icon(Icons.add),
                  label: Text('calendar_add_note'.tr()),
                  style: ElevatedButton.styleFrom(
                    iconColor: Colors.black,
                    backgroundColor: Colors.amber.shade300,
                    foregroundColor: Colors.black,
                  ),
                ),
              ),
            ],
            actionsPadding: const EdgeInsets.only(right: 16, bottom: 16),
          ),
    );
  }

  Widget _buildNoteItem(Nota nota, DateTime day, bool isStarted) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isStarted ? Colors.amber.shade300 : Colors.amber.shade100,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.access_time, size: 14),
              const SizedBox(width: 4),
              Text(
                nota.horarecordatorio,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(nota.comentario)),
              IconButton(
                icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  Navigator.pop(context);
                  _showAddNoteDialog(day, nota);
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () async {
                  if (nota.id != null) {
                    try {
                      await noteService.deleteNote(nota.id!);
                      await _loadUserNotes();
                      if (mounted) {
                        Navigator.pop(context);
                        _showActivitiesDialog(day);
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'calendar_error_deleting_note'.tr(
                                args: [e.toString()],
                              ),
                            ),
                          ),
                        );
                      }
                    }
                  }
                },
              ),
            ],
          ),
          if (isStarted)
            Text(
              'calendar_time_passed'.tr(),
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.orange.shade800,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity, bool isStarted) {
    final activityColor = _getActivityColor(activity);
    final startTime = DateTime.parse(activity['dataInici']);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isStarted ? Colors.grey.shade200 : Colors.white,
        border: Border.all(color: activityColor, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: ListTile(
        leading: Container(
          width: 12,
          height: double.infinity,
          decoration: BoxDecoration(
            color: activityColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        title: Row(
          children: [
            Text(
              DateFormat('HH:mm').format(startTime),
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                activity['nom'] ?? 'calendar_no_name'.tr(),
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${'calendar_creator'.tr()}${activity['creador']}'),
            Text('calendar_end'.tr() + _formatDateTime(activity['dataFi'])),
            if (isStarted)
              Text(
                'calendar_already_started'.tr(),
                style: TextStyle(
                  color: Colors.red,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
        contentPadding: const EdgeInsets.only(
          left: 8,
          top: 2,
          bottom: 2,
          right: 8,
        ),
        onTap: () {
          Navigator.pop(context);
          _navigateToActivityDetails(activity);
        },
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
              onEdit: () => _showEditActivityForm(activity),
              onDelete: () => _showDeleteConfirmation(activity),
            ),
      ),
    );
  }

  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null) return 'N/A';

    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
    } catch (e) {
      return dateTimeStr;
    }
  }

  Future<void> fetchAirQualityData() async {
    try {
      await mapService.fetchAirQualityData(contaminantsPerLocation);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'calendar_error_loading_air_quality'.tr(args: [e.toString()]),
            ),
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

  void _showEditActivityForm(Map<String, dynamic> activity) {
    final parentContext = context; // capture scaffold context
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController(text: activity['nom']);
    final descriptionController = TextEditingController(
      text: activity['descripcio'],
    );
    final startDateController = TextEditingController(
      text: activity['dataInici'],
    );
    final endDateController = TextEditingController(text: activity['dataFi']);
    final creatorController = TextEditingController(text: activity['creador']);
    final locationController = TextEditingController(
      text:
          activity['ubicacio'] != null
              ? '${activity['ubicacio']['latitud']},${activity['ubicacio']['longitud']}'
              : '',
    );

    showDialog(
      context: parentContext,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('edit_activity'.tr()),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleController,
                    decoration: InputDecoration(labelText: 'title'.tr()),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'please_title'.tr();
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: descriptionController,
                    decoration: InputDecoration(labelText: 'description'.tr()),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'please_description'.tr();
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: startDateController,
                    decoration: InputDecoration(labelText: 'start_date'.tr()),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'please_start_date'.tr();
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: endDateController,
                    decoration: InputDecoration(labelText: 'end_date'.tr()),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'please_end_date'.tr();
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  Navigator.of(dialogContext).pop();

                  final updatedActivityData = {
                    'title': titleController.text,
                    'description': descriptionController.text,
                    'startDate': startDateController.text,
                    'endDate': endDateController.text,
                    'location': locationController.text,
                    'user': creatorController.text,
                  };

                  try {
                    final activityService = ActivityService();
                    await activityService.updateActivityInBackend(
                      activity['id'].toString(),
                      updatedActivityData,
                    );
                    if (mounted) {
                      if (!parentContext.mounted) return;
                      ScaffoldMessenger.of(parentContext).showSnackBar(
                        SnackBar(
                          content: Text('activity_updated_success'.tr()),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      // Get only the part after the last ': '
                      final parts = e.toString().split(': ');
                      String msg = parts.isNotEmpty ? parts.last : e.toString();
                      if (msg.contains("inapropiats")) {
                        msg = "inappropiat_message".tr();
                      }
                      if (!parentContext.mounted) return;
                      ScaffoldMessenger.of(
                        parentContext,
                      ).showSnackBar(SnackBar(content: Text(msg)));
                    }
                  }
                }
              },
              child: Text('save'.tr()),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> _showDeleteConfirmation(Map<String, dynamic> activity) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(tr('confirm_delete_activity_title')),
          content: Text(tr('confirm_delete_activity_content')),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context,false); // Cierra el diálogo
              },
              child: Text(tr('cancel')),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context,true); // Cierra el diálogo

                // Llama al servicio para eliminar la actividad
                try {
                  final activityService = ActivityService();
                  await activityService.deleteActivityFromBackend(
                    activity['id'].toString(),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(tr('activity_deleted_success'))),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          tr('activity_delete_error', args: [e.toString()]),
                        ),
                      ),
                    );
                  }
                }
              },
              child: Text(tr('delete'), style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}
