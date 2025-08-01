import 'car_configuration.dart';

class ClientMessage {
  final String type;
  final Map<String, dynamic> data;

  const ClientMessage._(this.type, this.data);

  factory ClientMessage.control({
    required int steering,
    required int throttle,
  }) {
    assert(steering >= -100 && steering <= 100);
    assert(throttle >= -100 && throttle <= 100);
    return ClientMessage._('control', {
      'steering': steering,
      'throttle': throttle,
    });
  }

  factory ClientMessage.configUpdate(CarConfiguration config) =>
      ClientMessage._('config_update', {'config': config.toJson()});

  factory ClientMessage.configRequest() =>
      ClientMessage._('config_request', {});

  factory ClientMessage.ping(int timestamp) =>
      ClientMessage._('ping', {'timestamp': timestamp});

  Map<String, dynamic> toJson() => {'type': type, ...data};
}
