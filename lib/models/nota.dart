class Nota {
  final int? id;
  final String username;
  final DateTime fechacreacion;
  final String horarecordatorio;
  final String comentario;

  Nota({
    this.id,
    required this.username,
    required this.fechacreacion,
    required this.horarecordatorio,
    required this.comentario,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'fecha_creacion': "${fechacreacion.year}-${fechacreacion.month.toString().padLeft(2, '0')}-${fechacreacion.day.toString().padLeft(2, '0')}",
      'hora_recordatorio': horarecordatorio,
      'comentario': comentario,
    };
  }

  factory Nota.fromJson(Map<String, dynamic> json) {
    return Nota(
      id: json['id'],
      username: json['username'],
      fechacreacion: DateTime.parse(json['fechaCreacion']),
      horarecordatorio: json['horaRecordatorio'],
      comentario: json['comentario'],
    );
  }
}