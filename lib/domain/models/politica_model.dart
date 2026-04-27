class PoliticaModel {
  final String id;
  final String nombre;
  final String descripcion;

  PoliticaModel({
    required this.id,
    required this.nombre,
    required this.descripcion,
  });

  factory PoliticaModel.fromJson(Map<String, dynamic> json) {
    return PoliticaModel(
      id: json['id'],
      nombre: json['nombre'],
      descripcion: json['descripcion'],
    );
  }
}