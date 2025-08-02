import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cockpit/models/car_configuration.dart';
import 'package:cockpit/src/rust/api/models.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import '../models/radio_connection_state.dart';
import '../models/client_message.dart';
import '../models/server_message.dart';

class UdpRadioService extends ChangeNotifier {
  static final _logger = Logger(
    printer: PrettyPrinter(methodCount: 0, colors: true, printEmojis: false),
  );

  RawDatagramSocket? _socket;
  InternetAddress? _serverAddress;
  int? _serverPort;
  RadioConnectionState _state = RadioConnectionState.disconnected;
  String _lastError = '';
  CarConfiguration? _carConfig;
  Timer? _pingTimer;
  bool _disposed = false;

  final StreamController<ServerMessage> _messageController =
      StreamController.broadcast();

  RadioConnectionState get connectionState => _state;
  String get lastError => _lastError;
  CarConfiguration? get carConfig => _carConfig;
  Stream<ServerMessage> get messageStream => _messageController.stream;

  bool get _isConnected =>
      _socket != null && _serverAddress != null && _serverPort != null;

  Future<bool> connect(F1Car car) async {
    if (car.ipAddress == null || car.port == null) {
      return _setError('Car does not have valid IP address or port');
    }

    _setState(RadioConnectionState.connecting);

    try {
      _logger.i(
        'Connecting to car ${car.number} at ${car.ipAddress}:${car.port}',
      );

      _serverAddress = InternetAddress(car.ipAddress!);
      _serverPort = car.port!;
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _socket!.listen(_handleIncomingData);

      // Wait a bit for socket to be ready
      await Future.delayed(const Duration(milliseconds: 100));

      // Test connection with initial ping
      await _sendPing();

      // Give some time for the ping to process
      await Future.delayed(const Duration(milliseconds: 50));

      // Request configuration
      await sendMessage(ClientMessage.configRequest());

      // Start regular ping timer
      _startPingTimer();

      _setState(RadioConnectionState.connected);
      _logger.i('Successfully connected to car ${car.number}');
      return true;
    } catch (e) {
      _logger.e('Failed to connect: $e');
      await disconnect();
      return _setError('Failed to connect: $e');
    }
  }

  Future<void> disconnect({bool fromDispose = false}) async {
    _logger.i('Disconnecting from radio service');
    _pingTimer?.cancel();
    _socket?.close();
    _reset();
    if (!_disposed && !fromDispose) {
      _setState(RadioConnectionState.disconnected);
    }
  }

  void _reset() {
    _pingTimer = null;
    _socket = null;
    _serverAddress = null;
    _serverPort = null;
    _carConfig = null;
  }

  Future<bool> sendMessage(ClientMessage message) async {
    if (!_isConnected) {
      _logger.w('Cannot send message: not connected');
      return false;
    }

    try {
      final data = utf8.encode(jsonEncode(message.toJson()));
      final sent = _socket!.send(data, _serverAddress!, _serverPort!);

      if (sent == data.length) {
        _logger.d('Sent message: ${message.type}');
        return true;
      } else {
        _logger.w('Partial send: $sent of ${data.length} bytes');
        // If we get 0 bytes sent, this might indicate a permission or socket error
        if (sent == 0) {
          return _setError('Send failed - check network permissions');
        }
        return false;
      }
    } catch (e) {
      _logger.e('Failed to send message: $e');
      // Handle specific socket errors
      if (e.toString().contains('Operation not permitted')) {
        return _setError('Network permission denied - check Android manifest');
      }
      return _setError('Failed to send message: $e');
    }
  }

  Future<bool> sendControl({
    required int steering,
    required int throttle,
  }) async => sendMessage(
    ClientMessage.control(steering: steering, throttle: throttle),
  );

  void _handleIncomingData(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;

    final datagram = _socket?.receive();
    if (datagram == null) return;

    try {
      final json =
          jsonDecode(utf8.decode(datagram.data)) as Map<String, dynamic>;
      final message = ServerMessage.fromJson(json);

      _logger.d('Received message: ${json['type']}');

      if (message is ConfigMessage) {
        _carConfig = message.config;
        if (!_disposed) {
          notifyListeners();
        }
      }

      _messageController.add(message);
    } catch (e) {
      _logger.e('Failed to parse message: $e');
    }
  }

  Future<void> _sendPing() async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await sendMessage(ClientMessage.ping(timestamp));
  }

  void _startPingTimer() {
    _pingTimer = Timer.periodic(const Duration(seconds: 5), (_) => _sendPing());
  }

  void _setState(RadioConnectionState state) {
    if (_disposed) return; // Don't notify if disposed
    if (_state != state) {
      _state = state;
      notifyListeners();
    }
  }

  bool _setError(String error) {
    _lastError = error;
    _setState(RadioConnectionState.error);
    return false;
  }

  @override
  void dispose() {
    _disposed = true;
    disconnect(fromDispose: true);
    _messageController.close();
    super.dispose();
  }
}
