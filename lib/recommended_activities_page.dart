import 'dart:convert';
import 'dart:io';

import 'package:airplan/air_quality.dart';
import 'package:airplan/air_quality_service.dart';
import 'package:airplan/map_service.dart';
import 'package:airplan/services/api_config.dart';
import 'package:airplan/services/auth_service.dart';
import 'package:airplan/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:airplan/transit_service.dart';
import 'package:easy_localization/easy_localization.dart';

import 'activity_details_page.dart';
import 'activity_service.dart';

class Activity {
  int id;
  String creador;
  String name;
  String description;
  DateTime dataInici;
  DateTime dataFi;
  LatLng location;
  double distance;
  bool isFavorite;
  List<AirQualityData> airQuality;

  Activity({
    required this.id,
    required this.creador,
    required this.name,
    required this.description,
    required this.dataInici,
    required this.dataFi,
    required this.location,
    required this.distance,
    required this.isFavorite,
    required this.airQuality,
  });
}

class RecommendedActivitiesPage extends StatefulWidget {
  final LatLng userLocation;
  final Map<LatLng, Map<Contaminant, AirQualityData>> contaminantsPerLocation;
  final Map<LatLng, String> savedLocations;

  const RecommendedActivitiesPage({
    super.key,
    required this.userLocation,
    required this.contaminantsPerLocation,
    required this.savedLocations,
  });

  @override
  RecommendedActivitiesPageState createState() =>
      RecommendedActivitiesPageState();
}

class RecommendedActivitiesPageState extends State<RecommendedActivitiesPage> {
  List<Activity> _activities = [];
  bool _isLoading = true;
  int _totalActivities = 0;
  int _loadedActivities = 0;
  final activityService = ActivityService();
  final authService = AuthService();
  bool _error = false;
  String _reason = '';

  @override
  void initState() {
    super.initState();
    _fetchRecommendedActivities().then((_) {
      setState(() {
        _isLoading = false;
      });
    });
  }

  Future<void> _fetchRecommendedActivities() async {
    final url = Uri.parse(ApiConfig().buildUrl("api/activitats/recomanades"));
    final response = await http.get(
      url.replace(
        queryParameters: {
          'latitud': widget.userLocation.latitude.toString(),
          'longitud': widget.userLocation.longitude.toString(),
        },
      ),
    );
    if (response.statusCode == 200) {
      final body = utf8.decode(response.bodyBytes);
      final activitats = jsonDecode(body);
      setState(() {
        _totalActivities = activitats.length;
        _loadedActivities = 0;
      });
      for (var activitat in activitats) {
        LatLng localitzacioActivitat = LatLng(
          activitat['ubicacio']['latitud'],
          activitat['ubicacio']['longitud'],
        );
        List<AirQualityData> aqd = AirQualityService.findClosestAirQualityData(
          localitzacioActivitat,
          widget.contaminantsPerLocation,
        );
        if (AirQualityService.isAcceptable(aqd)) {
          TransitRoute dist = await calculateRoute(
            false,
            false,
            DateTime.now(),
            DateTime.now(),
            3,
            widget.userLocation,
            localitzacioActivitat,
          );
          Activity temp = Activity(
            id: activitat['id'],
            creador: activitat['creador'],
            name: activitat['nom'],
            description: activitat['descripcio'],
            dataInici: DateTime.parse(activitat['dataInici']),
            dataFi: DateTime.parse(activitat['dataFi']),
            location: localitzacioActivitat,
            distance: dist.distance.toDouble(),
            isFavorite: await activityService.isActivityFavorite(
              activitat['id'],
              authService.getCurrentUsername()!,
            ),
            airQuality: aqd,
          );
          try {
            widget.savedLocations[localitzacioActivitat] = await MapService()
                .fetchPlaceDetails(localitzacioActivitat);
          } catch (e) {
            widget.savedLocations[localitzacioActivitat] = "";
          }
          _activities.add(temp);
        }
        setState(() {
          _loadedActivities++;
        });
      }
      setState(() {
        _activities = _activities;
      });
    } else {
      _error = true;
      if (response.statusCode == HttpStatus.serviceUnavailable) {
        _reason = 'recommended_activities_error_no_activities_nearby'.tr();
      } else if (response.statusCode == HttpStatus.internalServerError && utf8.decode(response.bodyBytes) == "No hi han activitats al sistema.") {
        _reason = 'recommended_activities_error_no_activities_in_system'.tr();
      } else {
        _reason = 'recommended_activities_error_server_or_communication'.tr();
      }
    }
  }

  void _showEditActivityForm(Activity activity) {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController(text: activity.name);
    final descriptionController = TextEditingController(
      text: activity.description,
    );
    final startDateController = TextEditingController(
      text: activity.dataInici.toString(),
    );
    final endDateController = TextEditingController(
      text: activity.dataFi.toString(),
    );
    final creatorController = TextEditingController(text: activity.creador);
    final locationController = TextEditingController(
      text: '${activity.location.latitude},${activity.location.longitude}',
    );

    LatLng selectedLocation = activity.location;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('edit_activity_button'.tr()),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'recommended_activities_title_label'.tr(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'recommended_activities_error_empty_title'.tr();
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: descriptionController,
                    decoration: InputDecoration(
                      labelText:
                          'recommended_activities_description_label'.tr(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'recommended_activities_error_empty_description'
                            .tr();
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: startDateController,
                    decoration: InputDecoration(
                      labelText: 'recommended_activities_start_date_label'.tr(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'recommended_activities_error_empty_start_date'
                            .tr();
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: endDateController,
                    decoration: InputDecoration(
                      labelText: 'recommended_activities_end_date_label'.tr(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'recommended_activities_error_empty_end_date'
                            .tr();
                      }
                      return null;
                    },
                  ),
                  DropdownButtonFormField<LatLng>(
                    value: selectedLocation,
                    items:
                        widget.savedLocations.entries.map((entry) {
                          String displayText =
                              entry.value.isNotEmpty
                                  ? entry.value
                                  : '${entry.key.latitude}, ${entry.key.longitude}';
                          return DropdownMenuItem<LatLng>(
                            value: entry.key,
                            child: Text(
                              displayText,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedLocation = value!;
                      });
                    },
                    decoration: InputDecoration(
                      labelText: 'recommended_activities_location_label'.tr(),
                    ),
                    validator: (value) {
                      if (value == null) {
                        return 'recommended_activities_error_empty_location'
                            .tr();
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
                Navigator.pop(context); // Cierra el diálogo
              },
              child: Text('cancel'.tr()),
            ),
            TextButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  // Cierra el diálogo
                  Navigator.pop(context);

                  // Prepara los datos actualizados
                  final updatedActivityData = {
                    'title': titleController.text,
                    'description': descriptionController.text,
                    'startDate': startDateController.text,
                    'endDate': endDateController.text,
                    'location':
                        locationController
                            .text, // Ubicación ingresada por el usuario
                    'user': creatorController.text,
                  };

                  // Llama al servicio para actualizar la actividad
                  try {
                    final activityService = ActivityService();
                    await activityService.updateActivityInBackend(
                      activity.id.toString(),
                      updatedActivityData,
                    );
                    // TODO: Consider adding a success message, e.g., 'activity_updated_success'.tr()
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'recommended_activities_update_error'.tr() +
                                e.toString(),
                          ),
                        ),
                      );
                    }
                  }
                }
              },
              child: Text('common_save_button'.tr()),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmation(Activity activity) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('delete_activity_button'.tr()),
          content: Text('recommended_activities_confirm_delete_message'.tr()),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Cierra el diálogo
              },
              child: Text('cancel'.tr()),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context); // Cierra el diálogo

                // Llama al servicio para eliminar la actividad
                try {
                  final activityService = ActivityService();
                  await activityService.deleteActivityFromBackend(
                    activity.id.toString(),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("activity_deleted_success".tr())),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'activity_delete_error'.tr() + e.toString(),
                        ),
                      ),
                    );
                  }
                }
              },
              child: Text(
                'delete_button_label'.tr(),
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('recommended_activities_page_title'.tr()),
        backgroundColor: Colors.teal,
      ),
      body:
          _isLoading
              ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Center(child: CircularProgressIndicator()),
                  if (_totalActivities > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24.0,
                        vertical: 16.0,
                      ),
                      child: Column(
                        children: [
                          LinearProgressIndicator(
                            value:
                                _totalActivities > 0
                                    ? _loadedActivities / _totalActivities
                                    : null,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${'recommended_activities_loading_text'.tr()}$_loadedActivities / $_totalActivities',
                          ),
                        ],
                      ),
                    ),
                ],
              )
              : _error
                  ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Text(
                        _reason,
                        style: TextStyle(
                          color: Colors.red[700],
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                  : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'recommended_activities_section_title'.tr(),
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.teal[900],
                            fontSize: 18,
                          ) ??
                          TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.teal[900],
                            fontSize: 18,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const Divider(thickness: 1.2, indent: 24, endIndent: 24),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _activities.length,
                      itemBuilder: (context, index) {
                        final activity = _activities[index];
                        return InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => ActivityDetailsPage(
                                      id: activity.id.toString(),
                                      title: activity.name,
                                      creator: activity.creador,
                                      description: activity.description,
                                      startDate: activity.dataInici.toString(),
                                      endDate: activity.dataFi.toString(),
                                      airQualityData: activity.airQuality,
                                      isEditable: true,
                                      onEdit:
                                          () => _showEditActivityForm(
                                            activity,
                                          ), // Pasamos la función de editar
                                      onDelete:
                                          () => _showDeleteConfirmation(
                                            activity,
                                          ), // Pasamos la función de eliminar
                                    ),
                              ),
                            );
                          },
                          child: Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 8.0,
                            ),
                            elevation: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: GestureDetector(
                                              onTap: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder:
                                                        (
                                                          context,
                                                        ) => ActivityDetailsPage(
                                                          id:
                                                              activity.id
                                                                  .toString(),
                                                          title: activity.name,
                                                          creator:
                                                              activity.creador,
                                                          description:
                                                              activity
                                                                  .description,
                                                          startDate:
                                                              activity.dataInici
                                                                  .toString(),
                                                          endDate:
                                                              activity.dataFi
                                                                  .toString(),
                                                          airQualityData:
                                                              activity
                                                                  .airQuality,
                                                          isEditable: true,
                                                          onEdit:
                                                              () => _showEditActivityForm(
                                                                activity,
                                                              ), // Pasamos la función de editar
                                                          onDelete:
                                                              () => _showDeleteConfirmation(
                                                                activity,
                                                              ), // Pasamos la función de eliminar
                                                        ),
                                                  ),
                                                );
                                              },
                                              child: Text(
                                                activity.name,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Chip(
                                            backgroundColor: Colors.teal[100],
                                            label: Text(
                                              activity.distance < 1000
                                                  ? '${activity.distance.toStringAsFixed(0)} m'
                                                  : '${NumberFormat("#,##0.0", "es_ES").format(activity.distance / 1000)} km',
                                              style: TextStyle(
                                                color: Colors.teal[800],
                                              ),
                                            ),
                                            avatar: Icon(
                                              Icons.directions_walk,
                                              color: Colors.teal[800],
                                              size: 18,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        activity.description,
                                        style: TextStyle(
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.calendar_today,
                                            size: 16,
                                            color: Colors.teal[700],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${'start'.tr()}: ${DateFormat('dd/MM/yyyy HH:mm').format(activity.dataInici)}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.teal[900],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Icon(
                                            Icons.event,
                                            size: 16,
                                            color: Colors.teal[700],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${'end'.tr()}: ${DateFormat('dd/MM/yyyy HH:mm').format(activity.dataFi)}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.teal[900],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "air_quality_label".tr(),
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: Colors.teal[800],
                                              ),
                                              textAlign: TextAlign.left,
                                            ),
                                            const SizedBox(width: 8),
                                            ...activity.airQuality.map(
                                              (aq) => Padding(
                                                padding: const EdgeInsets.only(
                                                  right: 8.0,
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.circle,
                                                      color:
                                                          getColorForAirQuality(
                                                            aq.aqi,
                                                          ),
                                                      size: 16,
                                                    ),
                                                    const SizedBox(width: 2),
                                                    Text(
                                                      '${aq.contaminant.name}: ${aq.value.toStringAsFixed(1)} ${aq.units}',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: Colors.grey[700],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          ElevatedButton.icon(
                                            icon:
                                                activity.isFavorite
                                                    ? Icon(
                                                      Icons.favorite,
                                                      color: Colors.red,
                                                    )
                                                    : Icon(
                                                      Icons.favorite_border,
                                                      color: Colors.red,
                                                    ),
                                            label:
                                                activity.isFavorite
                                                    ? Text('saved'.tr())
                                                    : Text('save'.tr()),
                                            onPressed: () async {
                                              if (!activity.isFavorite) {
                                                try {
                                                  await activityService
                                                      .addActivityToFavorites(
                                                        activity.id,
                                                        authService
                                                            .getCurrentUsername()!,
                                                      );
                                                  setState(() {
                                                    activity.isFavorite = true;
                                                  });
                                                  if (context.mounted) {
                                                    NotificationService().showInfo(
                                                      context,
                                                      'added_to_favorites_message'
                                                          .tr(
                                                            args: [
                                                              activity.name,
                                                            ],
                                                          ),
                                                    );
                                                  }
                                                } catch (e) {
                                                  if (context.mounted) {
                                                    NotificationService().showError(
                                                      context,
                                                      'error_adding_to_favorites_message'
                                                          .tr(),
                                                    );
                                                  }
                                                }
                                              } else {
                                                try {
                                                  await activityService
                                                      .removeActivityFromFavorites(
                                                        activity.id,
                                                        authService
                                                            .getCurrentUsername()!,
                                                      );
                                                  setState(() {
                                                    activity.isFavorite = false;
                                                  });
                                                  if (context.mounted) {
                                                    NotificationService().showInfo(
                                                      context,
                                                      'removed_from_favorites_message'
                                                          .tr(
                                                            args: [
                                                              activity.name,
                                                            ],
                                                          ),
                                                    );
                                                  }
                                                } catch (e) {
                                                  if (context.mounted) {
                                                    NotificationService().showError(
                                                      context,
                                                      'error_removing_from_favorites_message'
                                                          .tr(
                                                            args: [
                                                              activity.name,
                                                            ],
                                                          ),
                                                    );
                                                  }
                                                }
                                              }
                                            },
                                          ),
                                          const SizedBox(height: 8),
                                          ElevatedButton.icon(
                                            icon: const Icon(Icons.directions),
                                            label: Text(
                                              'how_to_get_there_label'.tr(),
                                            ),
                                            onPressed: () {
                                              Navigator.pop(
                                                context,
                                                activity.location,
                                              );
                                            },
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
                      },
                    ),
                  ),
                ],
              ),
    );
  }
}
