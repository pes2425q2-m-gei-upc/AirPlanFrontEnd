class Nota {
  final int? id;
  final String username;
  final DateTime fecha_creacion;
  final String hora_recordatorio;
  final String comentario;

  Nota({
    this.id,
    required this.username,
    required this.fecha_creacion,
    required this.hora_recordatorio,
    required this.comentario,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'fecha_creacion': "${fecha_creacion.year}-${fecha_creacion.month.toString().padLeft(2, '0')}-${fecha_creacion.day.toString().padLeft(2, '0')}",
      'hora_recordatorio': hora_recordatorio,
      'comentario': comentario,
    };
  }

  factory Nota.fromJson(Map<String, dynamic> json) {
    return Nota(
      id: json['id'],
      username: json['username'],
      fecha_creacion: DateTime.parse(json['fechaCreacion']),
      hora_recordatorio: json['horaRecordatorio'],
      comentario: json['comentario'],
    );
  }
}