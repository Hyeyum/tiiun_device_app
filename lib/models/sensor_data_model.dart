// lib/models/sensor_data_model.dart
class SensorData {
  final String id;
  final int humidity;
  final int motion;
  final String timestamp;
  final DateTime parsedTimestamp;

  SensorData({
    required this.id,
    required this.humidity,
    required this.motion,
    required this.timestamp,
    required this.parsedTimestamp,
  });

  factory SensorData.fromJson(String id, Map<dynamic, dynamic> json) {
    final timestampStr = json['timestamp']?.toString() ?? '';

    return SensorData(
      id: id,
      humidity: _parseIntSafely(json['humidity']),
      motion: _parseIntSafely(json['motion']),
      timestamp: timestampStr,
      parsedTimestamp: _parseTimestamp(timestampStr),
    );
  }

  static int _parseIntSafely(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static DateTime _parseTimestamp(String timestamp) {
    try {
      // "2025-05-28 09:12:04" 형식 파싱
      if (timestamp.isNotEmpty) {
        return DateTime.parse(timestamp.replaceAll(' ', 'T'));
      }
    } catch (e) {
      print('❌ Timestamp parsing error: $e');
    }
    return DateTime.now();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'humidity': humidity,
      'motion': motion,
      'timestamp': timestamp,
    };
  }

  @override
  String toString() {
    return 'SensorData(id: $id, humidity: $humidity, motion: $motion, timestamp: $timestamp)';
  }

  // 비교 연산자 (정렬용)
  bool operator >(SensorData other) {
    return parsedTimestamp.isAfter(other.parsedTimestamp);
  }

  bool operator <(SensorData other) {
    return parsedTimestamp.isBefore(other.parsedTimestamp);
  }
}
