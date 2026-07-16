/// SOS インシデント。位置情報は SOS 時のみ・このモデルのみに載る。
class SosIncident {
  final String id;
  final String clientId;
  final String? clientName;
  final double? latitude;
  final double? longitude;
  final int batteryLevel;
  final DateTime firedAt;
  final DateTime? resolvedAt;

  const SosIncident({
    required this.id,
    required this.clientId,
    this.clientName,
    this.latitude,
    this.longitude,
    required this.batteryLevel,
    required this.firedAt,
    this.resolvedAt,
  });

  bool get hasLocation => latitude != null && longitude != null;
  bool get isResolved => resolvedAt != null;

  factory SosIncident.fromJson(Map<String, dynamic> json) => SosIncident(
        id: json['id'] as String,
        clientId: json['client_id'] as String,
        clientName: json['client_name'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        batteryLevel: (json['battery_level'] as num?)?.toInt() ?? 0,
        firedAt: DateTime.parse(json['fired_at'] as String),
        resolvedAt: json['resolved_at'] != null
            ? DateTime.tryParse(json['resolved_at'] as String)
            : null,
      );
}
