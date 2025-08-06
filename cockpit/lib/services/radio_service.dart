import 'dart:async';

import 'package:cockpit/src/rust/api/models.dart';
import 'package:cockpit/src/rust/api/radio.dart';
import 'package:flutter/foundation.dart';

enum RadioConnectionState { disconnected, connecting, connected, error }

class RadioService extends ChangeNotifier {
  final UdpRadioService _service = UdpRadioService();
  StreamSubscription<RadioEvent>? _subscription;

  RadioConnectionState _connectionState = RadioConnectionState.disconnected;
  RadioConnectionState get connectionState => _connectionState;

  String? _lastError;
  String? get lastError => _lastError;

  CarIdentity? _carIdentity;
  CarIdentity? get carIdentity => _carIdentity;

  CarPhysics? _carPhysics;
  CarPhysics? get carPhysics => _carPhysics;

  final StreamController<ServerMessage> _messageStreamController =
      StreamController.broadcast();
  Stream<ServerMessage> get messageStream => _messageStreamController.stream;

  Future<void> connect(F1Car car) async {
    if (_connectionState == RadioConnectionState.connected ||
        _connectionState == RadioConnectionState.connecting) {
      return;
    }

    _updateState(RadioConnectionState.connecting);

    try {
      final eventController = StreamController<RadioEvent>();
      await _service.connect(car: car);

      _subscription = eventController.stream.listen(
        (event) {
          event.when(
            connected: () {
              _updateState(RadioConnectionState.connected);
            },
            disconnected: () {
              _updateState(RadioConnectionState.disconnected);
            },
            message: (serverMessage) {
              _messageStreamController.add(serverMessage);
              serverMessage.when(
                identity: (identity) {
                  _carIdentity = identity;
                  notifyListeners();
                },
                physics: (physics) {
                  _carPhysics = physics;
                  notifyListeners();
                },
                pong: (timestamp) {
                  // Not yet implemented
                },
                identityUpdated: (success, message) {
                  // Not yet implemented
                },
                physicsUpdated: (success, message) {
                  // Not yet implemented
                },
                error: (message) {
                  _lastError = message;
                  _updateState(RadioConnectionState.error);
                },
              );
            },
            error: (errorMessage) {
              _lastError = errorMessage;
              _updateState(RadioConnectionState.error);
            },
          );
        },
        onError: (e) {
          _lastError = e.toString();
          _updateState(RadioConnectionState.error);
        },
        onDone: () {
          _updateState(RadioConnectionState.disconnected);
        },
      );
    } catch (e) {
      _lastError = e.toString();
      _updateState(RadioConnectionState.error);
    }
  }

  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;
    _updateState(RadioConnectionState.disconnected);
  }

  void _updateState(RadioConnectionState state) {
    if (_connectionState == state) return;
    _connectionState = state;
    notifyListeners();
  }

  Future<void> sendControl({
    required int steering,
    required int throttle,
  }) async {
    if (_connectionState != RadioConnectionState.connected) return;
    await _service.sendControl(steering: steering, throttle: throttle);
  }

  Future<void> ping() async {
    if (_connectionState != RadioConnectionState.connected) return;
    await _service.ping();
  }

  Future<void> updateIdentity(CarIdentity identity) async {
    if (_connectionState != RadioConnectionState.connected) return;
    await _service.updateIdentity(identity: identity);
  }

  Future<void> updatePhysics(CarPhysics physics) async {
    if (_connectionState != RadioConnectionState.connected) return;
    await _service.updatePhysics(physics: physics);
  }

  @override
  void dispose() {
    disconnect();
    _messageStreamController.close();
    super.dispose();
  }
}
