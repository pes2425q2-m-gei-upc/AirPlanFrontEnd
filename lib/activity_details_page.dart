import 'dart:convert';
import 'package:airplan/user_services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:airplan/air_quality.dart';
import 'package:airplan/solicituds_service.dart';
import 'package:airplan/services/api_config.dart';
import 'package:airplan/services/notification_service.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:http/http.dart' as http;
import 'package:airplan/chat_detail_page.dart';
import 'invite_users_dialog.dart';
import 'package:easy_localization/easy_localization.dart';

class Valoracio {
  final String username;
  final int idActivitat;
  final double valoracion;
  final String? comentario;
  final DateTime fecha;

  Valoracio({
    required this.username,
    required this.idActivitat,
    required this.valoracion,
    this.comentario,
    required this.fecha,
  });

  factory Valoracio.fromJson(Map<String, dynamic> json) {
    return Valoracio(
      username: json['username'],
      idActivitat: json['idActivitat'],
      valoracion: json['valoracion'].toDouble(),
      comentario: json['comentario'],
      fecha: DateTime.parse(json['fechaValoracion']),
    );
  }
}

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
  ActivityDetailsPageState createState() => ActivityDetailsPageState();
}

class ActivityDetailsPageState extends State<ActivityDetailsPage> {
  late Future<bool> _solicitudExistente;
  final NotificationService _notificationService = NotificationService();
  bool showParticipants = false;
  List<String> participants = []; // Aquí se cargan los participantes

  // Simulación de carga de participantes
  bool esExtern = false; // Por defecto, asumimos que no es externo
  Future<void> loadParticipants() async {
    final url = Uri.parse(
      ApiConfig().buildUrl('api/activitats/${widget.id}/participants'),
    ); // Asegúrate que el host es accesible

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        setState(() {
          participants = jsonList.map((e) => e.toString()).toList();
          showParticipants = true;
        });
      }
    } catch (e) {
      final actualContext = context;
      if (actualContext.mounted) {
        ScaffoldMessenger.of(
          actualContext,
        ).showSnackBar(SnackBar(content: Text('participants_load_error'.tr())));
      }
    }
  }

  Future<void> _esExtern() async {
    esExtern = (await UserService.getUserData(widget.creator))['esExtern'] ?? false;
    setState(() {
      esExtern = esExtern;
    });
  }

  @override
  void initState() {
    super.initState();
    _solicitudExistente = _checkSolicitudExistente();
    _esExtern(); // Cargar si el creador es externo
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
      await SolicitudsService().cancelarSolicitud(
        int.parse(widget.id),
        currentUser,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('request_cancel_success'.tr())));
    } else {
      // Enviar solicitud
      await SolicitudsService().sendSolicitud(
        int.parse(widget.id),
        currentUser,
        widget.creator,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('request_send_success'.tr())));
    }

    // Refresh the button state
    setState(() {
      _solicitudExistente = _checkSolicitudExistente();
    });
  }

  // Rating functionality methods
  Future<List<Valoracio>> fetchValoracions(String activityId) async {
    final backendUrl = Uri.parse(
      ApiConfig().buildUrl('valoracions/activitat/$activityId'),
    );

    try {
      final response = await http.get(backendUrl);

      if (response.statusCode == 200) {
        final body = utf8.decode(response.bodyBytes);
        final List<dynamic> data = jsonDecode(body);
        final List<Valoracio> valoracions =
            data.map((json) => Valoracio.fromJson(json)).toList();
        // Sort from newest to oldest
        valoracions.sort((a, b) => b.fecha.compareTo(a.fecha));
        return valoracions;
      } else {
        throw Exception('failed_to_load_ratings'.tr());
      }
    } catch (e) {
      throw Exception(
        'error_connecting_backend_detail'.tr(args: [e.toString()]),
      );
    }
  }

  Future<bool> checkUserHasRated(String activityId, String userId) async {
    final backendUrl = Uri.parse(
      ApiConfig().buildUrl('valoracions/usuario/$userId/activitat/$activityId'),
    );

    try {
      final response = await http.get(backendUrl);
      return response.statusCode == 200 && jsonDecode(response.body) != null;
    } catch (e) {
      return false;
    }
  }

  void saveRating({
    required String activityId,
    required String userId,
    required double rating,
    String? comment,
    required BuildContext context,
  }) async {
    final backendUrl = Uri.parse(ApiConfig().buildUrl('valoracions'));

    try {
      final response = await http.post(
        backendUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': userId,
          'idActivitat': int.parse(activityId),
          'valoracion': rating.toInt(),
          'comentario': comment,
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final String message = 'rating_saved_success'.tr();
        if (!context.mounted) return;
        _notificationService.showSuccess(context, message);
      } else {
        String message =
            response.body.isNotEmpty
                ? response.body
                : 'rating_saved_error'.tr();
        if (response.body.contains("inapropiat")) {
          message = 'inappropiat_message'.tr();
        }
        if (!context.mounted) return;
        _notificationService.showError(context, message);
      }
    } catch (e) {
      final String message = 'error_connecting_backend'.tr();
      if (!context.mounted) return;
      _notificationService.showError(context, message);
    }
  }

  Widget buildRatingAverage(List<Valoracio> valoracions) {
    if (valoracions.isEmpty) {
      return Text('no_ratings_yet'.tr(), style: TextStyle(fontSize: 16));
    }

    final double average =
        valoracions.map((v) => v.valoracion).reduce((a, b) => a + b) /
        valoracions.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'average_rating_label'.tr(),
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        SizedBox(height: 8),
        RatingBarIndicator(
          rating: average,
          itemBuilder:
              (context, index) => Icon(Icons.star, color: Colors.amber),
          itemCount: 5,
          itemSize: 30.0,
          direction: Axis.horizontal,
        ),
        Text(
          'average_rating_from_total'.tr() + average.toStringAsFixed(1),
          style: TextStyle(fontSize: 16),
        ),
      ],
    );
  }

  Widget buildValoracionItem(Valoracio valoracio) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  valoracio.username,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  '${valoracio.fecha.day}/${valoracio.fecha.month}/${valoracio.fecha.year}',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
            SizedBox(height: 8),
            RatingBarIndicator(
              rating: valoracio.valoracion,
              itemBuilder:
                  (context, index) => Icon(Icons.star, color: Colors.amber),
              itemCount: 5,
              itemSize: 20.0,
              direction: Axis.horizontal,
            ),
            if (valoracio.comentario != null &&
                valoracio.comentario!.isNotEmpty) ...[
              SizedBox(height: 8),
              Text(valoracio.comentario!, style: TextStyle(fontSize: 14)),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? currentUser = FirebaseAuth.instance.currentUser?.displayName;
    final bool isCurrentUserCreator =
        currentUser != null && widget.creator == currentUser;
    final bool canSendMessage = !isCurrentUserCreator && currentUser != null && !esExtern;
    final bool isActivityFinished = DateTime.now().isAfter(
      DateTime.parse(widget.endDate),
    );

    return Scaffold(
      appBar: AppBar(title: Text('activity_details_title'.tr())),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${'id_label'.tr()} ${widget.id}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              SizedBox(height: 16),
              Text(
                widget.title,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
              ),
              SizedBox(height: 16),
              Text(widget.description, style: TextStyle(fontSize: 16)),
              SizedBox(height: 16),
              Column(
                children:
                    widget.airQualityData.map((data) {
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
              Row(
                children: [
                  Icon(Icons.calendar_today),
                  SizedBox(width: 8),
                  Text(
                    '${'start_label'.tr()} ${widget.startDate}',
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
                    '${'end_label'.tr()} ${widget.endDate}',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person),
                      SizedBox(width: 8),
                      Text(
                        widget.creator,
                        style: TextStyle(color: Colors.purple, fontSize: 16),
                      ),
                    ],
                  ),
                  if (canSendMessage)
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) =>
                                    ChatDetailPage(username: widget.creator),
                          ),
                        );
                      },
                      icon: Icon(Icons.message),
                      label: Text('send_message_button'.tr()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                ],
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
                child: Text(
                  showParticipants
                      ? 'hide_participants'.tr()
                      : 'show_participants'.tr(),
                ),
              ),
              if (showParticipants)
                ...participants.map((p) {
                  bool isCurrentUser =
                      p ==
                      currentUser; // Verificamos si el participante es el usuario actual
                  return ListTile(
                    dense: true,
                    title: Text(p),
                    trailing:
                        isCurrentUserCreator && !isCurrentUser
                            ? IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder:
                                      (context) => AlertDialog(
                                        title: Text(
                                          'remove_participant_title'.tr(),
                                        ),
                                        content: Text(
                                          'remove_participant_message'.tr(
                                            args: [p],
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed:
                                                () => Navigator.pop(context,false),
                                            child: Text('cancel'.tr()),
                                          ),
                                          TextButton(
                                            onPressed:
                                                () => Navigator.pop(context,true),
                                            child: Text('delete'.tr()),
                                          ),
                                        ],
                                      ),
                                );
                                if (confirm == true) {
                                  final url = Uri.parse(
                                    ApiConfig().buildUrl(
                                      'api/activitats/${widget.id}/participants/$p',
                                    ),
                                  );

                                  try {
                                    final response = await http.delete(url);
                                    if (response.statusCode == 200) {
                                      setState(() {
                                        participants.remove(p);
                                      });
                                      final actualContext = context;
                                      if (actualContext.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'participant_removed_success'.tr(
                                                args: [p],
                                              ),
                                            ),
                                          ),
                                        );
                                      }
                                    } else {
                                      final actualContext = context;
                                      if (actualContext.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'error_removing_participant_detail'
                                                  .tr(args: [p]),
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  } catch (e) {
                                    final actualContext = context;
                                    if (actualContext.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'network_error_removing_participant_detail'
                                                .tr(args: [p]),
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                }
                              },
                            )
                            : null,
                  );
                }),

              SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.share),
                  SizedBox(width: 8),
                  Text(
                    'share_button_label'.tr(),
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
              SizedBox(height: 16),
              if (!isCurrentUserCreator && !esExtern)
                FutureBuilder<bool>(
                  future: _solicitudExistente,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CircularProgressIndicator();
                    } else if (snapshot.hasError) {
                      return Text('error_loading_request_status'.tr());
                    }

                    final solicitudExistente = snapshot.data ?? false;
                    return ElevatedButton(
                      onPressed:
                          () => _handleSolicitudAction(solicitudExistente),
                      child: Text(
                        solicitudExistente
                            ? 'cancel_request_button'.tr()
                            : 'request_to_join_button'.tr(),
                      ),
                    );
                  },
                ),
              if (isCurrentUserCreator) ...[
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder:
                          (context) => InviteUsersDialog(
                            activityId: widget.id,
                            creator: widget.creator,
                          ),
                    );
                  },
                  child: Text('invite_users_button'.tr()),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final solicitudes = await SolicitudsService().fetchSolicitudesUnio(widget.id);
                    if (!context.mounted) return;

                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('Solicitudes para unirse'),
                        content: solicitudes.isEmpty
                            ? Text('No hay solicitudes pendientes.')
                            : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: solicitudes.map((solicitud) {
                            return ListTile(
                              title: Text(solicitud),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.check, color: Colors.green),
                                    onPressed: () async {
                                      await SolicitudsService().aceptarSolicitudUnio(widget.id, solicitud);
                                      if (!context.mounted) return;
                                      Navigator.of(context).pop();
                                      setState(() {});
                                    },
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.close, color: Colors.red),
                                    onPressed: () async {
                                      await SolicitudsService().rechazarSolicitudUnio(widget.id, solicitud);
                                      if (!context.mounted) return;
                                      Navigator.of(context).pop();
                                      setState(() {});
                                    },
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  },
                  child: Text('Ver Solicitudes'),
                ),


                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: widget.onEdit,
                      child: Text('edit_activity_button'.tr()),
                    ),
                    ElevatedButton(
                      onPressed: widget.onDelete,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: Text('delete_activity_button'.tr()),
                    ),
                  ],
                ),
              ],

              // Rating functionality
              if (isActivityFinished) ...[
                SizedBox(height: 16),
                FutureBuilder<bool>(
                  future:
                      currentUser != null
                          ? checkUserHasRated(widget.id, currentUser)
                          : Future.value(false),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }

                    final bool hasRated = snapshot.data ?? false;

                    if (hasRated) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'already_rated_activity'.tr(),
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.grey[600],
                          ),
                        ),
                      );
                    }

                    return ElevatedButton(
                      onPressed: () async {
                        if (currentUser == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('user_not_authenticated'.tr()),
                            ),
                          );
                          return;
                        }

                        final parentContext =
                            context; // Capture the page context before showing dialog
                        showDialog(
                          context: context,
                          builder: (BuildContext dialogContext) {
                            double rating = 0;
                            TextEditingController commentController =
                                TextEditingController();

                            return AlertDialog(
                              title: Text('rate_activity_title'.tr()),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  RatingBar.builder(
                                    initialRating: 0,
                                    minRating: 1,
                                    direction: Axis.horizontal,
                                    allowHalfRating: false,
                                    itemCount: 5,
                                    itemBuilder:
                                        (context, _) => Icon(
                                          Icons.star,
                                          color: Colors.amber,
                                        ),
                                    onRatingUpdate: (value) {
                                      rating = value;
                                    },
                                  ),
                                  SizedBox(height: 16),
                                  TextField(
                                    controller: commentController,
                                    decoration: InputDecoration(
                                      labelText: 'optional_comment_label'.tr(),
                                      border: OutlineInputBorder(),
                                    ),
                                    maxLines: 3,
                                  ),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed:
                                      () => Navigator.of(dialogContext).pop(),
                                  child: Text('cancel_button'.tr()),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    saveRating(
                                      activityId: widget.id,
                                      userId: currentUser,
                                      rating: rating,
                                      comment: commentController.text,
                                      context: parentContext,
                                    );
                                    Navigator.of(dialogContext).pop();
                                    // Refresh the page
                                    setState(() {});
                                  },
                                  child: Text('submit_button'.tr()),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      child: Text('rate_activity_button'.tr()),
                    );
                  },
                ),
              ],

              // Rating display section
              SizedBox(height: 24),
              Text(
                'ratings_section_title'.tr(),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
              Divider(),
              FutureBuilder<List<Valoracio>>(
                future: fetchValoracions(widget.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Text(
                      'error_loading_ratings_detail'.tr(
                        args: [snapshot.error.toString()],
                      ),
                    );
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Column(
                      children: [
                        Text('no_ratings_yet_detail'.tr()),
                        SizedBox(height: 16),
                      ],
                    );
                  } else {
                    final valoracions = snapshot.data!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        buildRatingAverage(valoracions),
                        SizedBox(height: 16),
                        Text(
                          'all_ratings_label'.tr(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 8),
                        Column(
                          children:
                              valoracions
                                  .map((v) => buildValoracionItem(v))
                                  .toList(),
                        ),
                      ],
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String traduirContaminant(Contaminant contaminant) {
    switch (contaminant) {
      case Contaminant.so2:
        return 'SO2'; // Technical term, no direct translation needed for UI usually
      case Contaminant.pm10:
        return 'PM10'; // Technical term
      case Contaminant.pm2_5:
        return 'PM2.5'; // Technical term
      case Contaminant.no2:
        return 'NO2'; // Technical term
      case Contaminant.o3:
        return 'O3'; // Technical term
      case Contaminant.h2s:
        return 'H2S'; // Technical term
      case Contaminant.co:
        return 'CO'; // Technical term
      case Contaminant.c6h6:
        return 'C6H6'; // Technical term
    }
  }

  String traduirAQI(AirQuality aqi) {
    switch (aqi) {
      case AirQuality.excelent:
        return 'aqi_excellent'.tr();
      case AirQuality.bona:
        return 'aqi_good'.tr();
      case AirQuality.dolenta:
        return 'aqi_poor'.tr(); // Assuming 'dolenta' means poor/bad
      case AirQuality.pocSaludable:
        return 'aqi_unhealthy_sensitive'.tr(); // Or just 'aqi_unhealthy'
      case AirQuality.moltPocSaludable:
        return 'aqi_very_unhealthy'.tr();
      case AirQuality.perillosa:
        return 'aqi_hazardous'.tr();
    }
  }
}
