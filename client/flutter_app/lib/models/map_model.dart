class MapModel {
  final String id;
  final String name;
  final String? description;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;

  const MapModel({
    required this.id,
    required this.name,
    this.description,
    this.latitude,
    this.longitude,
    required this.createdAt,
  });

  factory MapModel.fromJson(Map<String, dynamic> json) {
    return MapModel(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  String get latitudeText =>
      latitude != null ? latitude!.toStringAsFixed(4) : '좌표 정보 없음';

  String get longitudeText =>
      longitude != null ? longitude!.toStringAsFixed(4) : '좌표 정보 없음';

  String get createdAtText =>
      '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
}
