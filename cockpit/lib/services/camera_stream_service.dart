import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

enum CameraConnectionState { disconnected, connecting, connected, error }

class CameraStreamService extends ChangeNotifier {
  static final _logger = Logger(
    printer: PrettyPrinter(methodCount: 0, colors: true, printEmojis: false),
  );

  RawDatagramSocket? _socket;
  InternetAddress? _serverAddress;
  CameraConnectionState _state = CameraConnectionState.disconnected;
  String _lastError = '';
  Uint8List? _latestFrame;
  int _frameCount = 0;
  bool _disposed = false;

  final StreamController<Uint8List> _frameController =
      StreamController<Uint8List>.broadcast();

  CameraConnectionState get connectionState => _state;
  String get lastError => _lastError;
  Uint8List? get latestFrame => _latestFrame;
  int get frameCount => _frameCount;
  Stream<Uint8List> get frameStream => _frameController.stream;

  bool get _isConnected => _socket != null && _serverAddress != null;

  Future<bool> connect(String ipAddress, {int port = 8082}) async {
    if (_state == CameraConnectionState.connecting) {
      _logger.w('Already connecting to camera stream');
      return false;
    }

    _setState(CameraConnectionState.connecting);
    _clearError();

    try {
      _logger.i('Connecting to camera stream at $ipAddress:$port');

      _serverAddress = InternetAddress(ipAddress);
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _socket!.listen(_handleIncomingData);

      // Wait for socket to be ready
      await Future.delayed(const Duration(milliseconds: 100));

      // Subscribe to camera stream
      await _subscribeToCameraStream(port);

      _setState(CameraConnectionState.connected);
      _logger.i('Successfully connected to camera stream');
      return true;
    } catch (e) {
      _logger.e('Failed to connect to camera stream: $e');
      await disconnect();
      return _setError('Failed to connect: $e');
    }
  }

  Future<void> disconnect({bool fromDispose = false}) async {
    if (_socket != null && _serverAddress != null) {
      try {
        // Send unsubscribe message
        await _unsubscribeFromCameraStream();
      } catch (e) {
        _logger.w('Failed to send unsubscribe message: $e');
      }
    }

    _logger.i('Disconnecting from camera stream');
    _socket?.close();
    _reset();

    if (!_disposed && !fromDispose) {
      _setState(CameraConnectionState.disconnected);
    }
  }

  Future<void> _subscribeToCameraStream(int port) async {
    if (!_isConnected) return;

    try {
      final subscribeMsg = utf8.encode("CAMERA_SUBSCRIBE");
      final sent = _socket!.send(subscribeMsg, _serverAddress!, port);

      if (sent == subscribeMsg.length) {
        _logger.d('Sent camera subscription request');
      } else {
        throw Exception('Failed to send subscription message');
      }
    } catch (e) {
      _logger.e('Failed to subscribe to camera stream: $e');
      rethrow;
    }
  }

  Future<void> _unsubscribeFromCameraStream() async {
    if (!_isConnected) return;

    try {
      final unsubscribeMsg = utf8.encode("CAMERA_UNSUBSCRIBE");
      _socket!.send(unsubscribeMsg, _serverAddress!, 8082);
      _logger.d('Sent camera unsubscribe request');
    } catch (e) {
      _logger.w('Failed to send unsubscribe message: $e');
    }
  }

  void _handleIncomingData(RawSocketEvent event) {
    if (event != RawSocketEvent.read || _disposed) return;

    final datagram = _socket?.receive();
    if (datagram == null) return;

    try {
      final data = datagram.data;

      // Check if this is a JPEG frame (starts with FF D8)
      if (data.length > 2 && data[0] == 0xFF && data[1] == 0xD8) {
        _frameCount++;
        _latestFrame = Uint8List.fromList(data);

        // _logger.d('Received camera frame $_frameCount: ${data.length} bytes');

        // Notify listeners and stream subscribers immediately
        if (!_disposed) {
          notifyListeners();
          _frameController.add(_latestFrame!);
        }
      } else {
        _logger.w('Received non-JPEG data: ${data.length} bytes');
      }
    } catch (e) {
      _logger.e('Failed to process camera frame: $e');
    }
  }

  void _reset() {
    _socket = null;
    _serverAddress = null;
    _latestFrame = null;
    _frameCount = 0;
  }

  void _setState(CameraConnectionState state) {
    if (_disposed) return;
    if (_state != state) {
      _state = state;
      notifyListeners();
    }
  }

  bool _setError(String error) {
    _lastError = error;
    _setState(CameraConnectionState.error);
    return false;
  }

  void _clearError() {
    _lastError = '';
  }

  @override
  void dispose() {
    _disposed = true;
    disconnect(fromDispose: true);
    _frameController.close();
    super.dispose();
  }
}
