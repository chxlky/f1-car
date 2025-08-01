import 'car_configuration.dart';

sealed class ServerMessage {
  factory ServerMessage.fromJson(Map<String, dynamic> json) {
    return switch (json['type']) {
      'config' => ConfigMessage.fromJson(json),
      'config_updated' => ConfigUpdatedMessage.fromJson(json),
      'pong' => PongMessage.fromJson(json),
      _ => throw Exception('Unknown message type: ${json['type']}'),
    };
  }
}

class ConfigMessage implements ServerMessage {
  final CarConfiguration config;
  ConfigMessage(this.config);
  factory ConfigMessage.fromJson(Map<String, dynamic> json) =>
      ConfigMessage(CarConfiguration.fromJson(json['config']));
}

class ConfigUpdatedMessage implements ServerMessage {
  final bool success;
  final String message;
  ConfigUpdatedMessage(this.success, this.message);
  factory ConfigUpdatedMessage.fromJson(Map<String, dynamic> json) =>
      ConfigUpdatedMessage(json['success'], json['message']);
}

class PongMessage implements ServerMessage {
  final int timestamp;
  PongMessage(this.timestamp);
  factory PongMessage.fromJson(Map<String, dynamic> json) =>
      PongMessage(json['timestamp']);
}
