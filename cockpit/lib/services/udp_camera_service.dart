import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';

enum CameraConnectionState { disconnected, connecting, connected, error }

class UdpCameraService extends ChangeNotifier {
  static const String _defaultHost = '192.168.0.213';
  static const int _defaultPort = 8081;

  RawDatagramSocket? _socket;
  StreamController<Uint8List>? _frameController;

  final Map<int, Map<int, Uint8List>> _frameChunks = {};
  final Map<int, int> _frameTotalChunks = {};

  CameraConnectionState _state = CameraConnectionState.disconnected;
  String _lastError = '';
  Uint8List? _latestFrame;
  int _frameCount = 0;
  bool _disposed = false;
  bool _cameraStreaming = false;

  // Debugging counters
  int _packetsReceived = 0;
  int _discoveryResponsesReceived = 0;

  Timer? _discoveryTimer;
  Timer? _keepAliveTimer;

  String _host = _defaultHost;
  int _port = _defaultPort;

  // Getters
  CameraConnectionState get connectionState => _state;
  String get lastError => _lastError;
  Uint8List? get latestFrame => _latestFrame;
  int get frameCount => _frameCount;
  String get host => _host;
  int get port => _port;
  int get packetsReceived => _packetsReceived;
  int get discoveryResponsesReceived => _discoveryResponsesReceived;
  bool get isCameraStreaming => _cameraStreaming;

  /// Stream of complete JPEG frames
  Stream<Uint8List> get frameStream =>
      _frameController?.stream ?? const Stream.empty();

  /// Connect to UDP camera server
  Future<bool> connect(String ipAddress, {int port = 8081}) async {
    if (_state == CameraConnectionState.connecting) {
      debugPrint('Already connecting to UDP camera stream');
      return false;
    }

    _setState(CameraConnectionState.connecting);
    _clearError();

    _host = ipAddress;
    _port = port;

    try {
      await _initializeSocket();
      await _discoverServer();
      _startKeepAlive();
      _setState(CameraConnectionState.connected);
      debugPrint(
        'Successfully connected to UDP camera stream at $ipAddress:$port',
      );
      return true;
    } catch (e) {
      debugPrint('Failed to connect to UDP camera stream: $e');
      await disconnect();
      return _setError('Failed to connect: $e');
    }
  }

  /// Start camera streaming
  Future<bool> startCamera() async {
    if (_socket == null || _state != CameraConnectionState.connected) {
      debugPrint('Cannot start camera: not connected');
      return false;
    }

    try {
      // Send start camera message
      final startMessage = 'START_CAMERA'.codeUnits;
      _socket!.send(startMessage, InternetAddress(_host), _port);
      debugPrint('Sent START_CAMERA command to $_host:$_port');
      return true;
    } catch (e) {
      debugPrint('Failed to send start camera command: $e');
      return false;
    }
  }

  /// Stop camera streaming
  Future<bool> stopCamera() async {
    if (_socket == null || _state != CameraConnectionState.connected) {
      debugPrint('Cannot stop camera: not connected');
      return false;
    }

    try {
      // Send stop camera message
      final stopMessage = 'STOP_CAMERA'.codeUnits;
      _socket!.send(stopMessage, InternetAddress(_host), _port);
      debugPrint('Sent STOP_CAMERA command to $_host:$_port');
      return true;
    } catch (e) {
      debugPrint('Failed to send stop camera command: $e');
      return false;
    }
  }

  /// Disconnect from UDP camera server
  Future<void> disconnect() async {
    _setState(CameraConnectionState.disconnected);
    _clearError();
    _cameraStreaming = false; // Reset camera streaming state

    _discoveryTimer?.cancel();
    _keepAliveTimer?.cancel();

    _socket?.close();
    _socket = null;

    await _frameController?.close();
    _frameController = null;

    _frameChunks.clear();
    _frameTotalChunks.clear();

    debugPrint('Disconnected from UDP camera stream');
  }

  Future<void> _initializeSocket() async {
    _frameController = StreamController<Uint8List>.broadcast();

    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    _socket!.listen(_handleDatagramPacket);

    debugPrint('UDP camera client bound to port ${_socket!.port}');
  }

  Future<void> _discoverServer() async {
    if (_socket == null) return;

    // Send discovery message
    final discoveryMessage = 'DISCOVER'.codeUnits;
    _socket!.send(discoveryMessage, InternetAddress(_host), _port);

    debugPrint('Sent camera discovery message to $_host:$_port');

    // Set up periodic discovery in case we lose connection
    _discoveryTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_state == CameraConnectionState.connected && _socket != null) {
        _socket!.send(discoveryMessage, InternetAddress(_host), _port);
        debugPrint('Re-sending camera discovery message');
      }
    });
  }

  void _startKeepAlive() {
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_state == CameraConnectionState.connected && _socket != null) {
        // Send keep-alive discovery message
        final keepAliveMessage = 'DISCOVER'.codeUnits;
        _socket!.send(keepAliveMessage, InternetAddress(_host), _port);
      }
    });
  }

  void _handleDatagramPacket(RawSocketEvent event) {
    if (event == RawSocketEvent.read) {
      final datagram = _socket!.receive();
      if (datagram != null) {
        _processDatagramData(datagram.data);
      }
    }
  }

  void _processDatagramData(Uint8List data) {
    _packetsReceived++;

    debugPrint(
      'Received UDP packet: ${data.length} bytes (total packets: $_packetsReceived)',
    );

    // Check for text responses first
    final message = String.fromCharCodes(data);

    // Check if this is a discovery response
    if (message.startsWith('CAMERA_SERVER')) {
      _discoveryResponsesReceived++;
      debugPrint(
        'Received discovery response from camera server (total: $_discoveryResponsesReceived)',
      );
      return;
    }

    // Check for camera control responses
    if (message.startsWith('CAMERA_STARTED')) {
      debugPrint('Camera streaming started successfully');
      _cameraStreaming = true;
      if (!_disposed) {
        notifyListeners();
      }
      return;
    }

    if (message.startsWith('CAMERA_STOPPED')) {
      debugPrint('Camera streaming stopped successfully');
      _cameraStreaming = false;
      if (!_disposed) {
        notifyListeners();
      }
      return;
    }

    if (message.startsWith('CAMERA_START_FAILED')) {
      debugPrint('Camera start failed');
      _cameraStreaming = false;
      if (!_disposed) {
        notifyListeners();
      }
      return;
    }

    if (message.startsWith('CAMERA_STOP_FAILED')) {
      debugPrint('Camera stop failed');
      // Keep current state since stop failed
      return;
    }

    if (message.startsWith('CAMERA_ALREADY_RUNNING')) {
      debugPrint('Camera is already running');
      _cameraStreaming = true;
      if (!_disposed) {
        notifyListeners();
      }
      return;
    }

    if (message.startsWith('CAMERA_ALREADY_STOPPED')) {
      debugPrint('Camera is already stopped');
      _cameraStreaming = false;
      if (!_disposed) {
        notifyListeners();
      }
      return;
    }

    // If we get here, it should be frame data
    if (data.length < 10) {
      debugPrint('Packet too small for frame data: ${data.length} bytes');
      return;
    }

    // Parse chunked frame packet: [frame_id:4][chunk_id:2][total_chunks:2][data_len:2][data...]
    final frameId = _bytesToInt32(data, 0);
    final chunkId = _bytesToInt16(data, 4);
    final totalChunks = _bytesToInt16(data, 6);
    final dataLen = _bytesToInt16(data, 8);

    debugPrint(
      'Frame packet - ID: $frameId, Chunk: $chunkId/$totalChunks, DataLen: $dataLen',
    );

    if (data.length < 10 + dataLen) {
      debugPrint(
        'Invalid packet: declared data length $dataLen but only ${data.length - 10} bytes available',
      );
      return;
    }

    final chunkData = data.sublist(10, 10 + dataLen);

    // Store chunk
    _frameChunks.putIfAbsent(frameId, () => <int, Uint8List>{});
    _frameChunks[frameId]![chunkId] = chunkData;
    _frameTotalChunks[frameId] = totalChunks;

    // Check if we have all chunks for this frame
    if (_frameChunks[frameId]!.length == totalChunks) {
      debugPrint('Frame $frameId complete with $totalChunks chunks');
      _reconstructFrame(frameId);
    }

    // Clean up old frames (keep only last 5 frames worth of chunks)
    final currentFrameIds = _frameChunks.keys.toList()..sort();
    if (currentFrameIds.length > 5) {
      for (int i = 0; i < currentFrameIds.length - 5; i++) {
        final oldFrameId = currentFrameIds[i];
        _frameChunks.remove(oldFrameId);
        _frameTotalChunks.remove(oldFrameId);
      }
    }
  }

  void _reconstructFrame(int frameId) {
    final chunks = _frameChunks[frameId]!;
    final totalChunks = _frameTotalChunks[frameId]!;

    // Calculate total frame size
    int totalSize = 0;
    for (int i = 0; i < totalChunks; i++) {
      if (chunks.containsKey(i)) {
        totalSize += chunks[i]!.length;
      } else {
        // Missing chunk, cannot reconstruct
        debugPrint('Missing chunk $i for frame $frameId');
        return;
      }
    }

    // Reconstruct the complete frame
    final frameData = Uint8List(totalSize);
    int offset = 0;

    for (int i = 0; i < totalChunks; i++) {
      final chunkData = chunks[i]!;
      frameData.setRange(offset, offset + chunkData.length, chunkData);
      offset += chunkData.length;
    }

    // Validate JPEG markers
    if (frameData.length >= 2 &&
        frameData[0] == 0xFF &&
        frameData[1] == 0xD8 &&
        frameData[frameData.length - 2] == 0xFF &&
        frameData[frameData.length - 1] == 0xD9) {
      // Valid JPEG frame, process it
      _frameCount++;
      _latestFrame = frameData;

      if (!_disposed) {
        notifyListeners();
        _frameController?.add(frameData);
      }

      // Clean up this frame's chunks
      _frameChunks.remove(frameId);
      _frameTotalChunks.remove(frameId);
    } else {
      debugPrint('Reconstructed frame $frameId is not a valid JPEG');
    }
  }

  int _bytesToInt32(Uint8List bytes, int offset) {
    return (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
  }

  int _bytesToInt16(Uint8List bytes, int offset) {
    return (bytes[offset] << 8) | bytes[offset + 1];
  }

  void _setState(CameraConnectionState newState) {
    if (_state != newState) {
      _state = newState;
      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  void _clearError() {
    if (_lastError.isNotEmpty) {
      _lastError = '';
      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  bool _setError(String error) {
    _lastError = error;
    _setState(CameraConnectionState.error);
    return false;
  }

  @override
  void dispose() {
    _disposed = true;
    disconnect();
    super.dispose();
  }

  /// Debug method to test UDP connectivity
  Future<String> testConnection({String? testHost, int? testPort}) async {
    final host = testHost ?? _host;
    final port = testPort ?? _port;

    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      debugPrint('Test socket bound to port ${socket.port}');

      final discoveryMessage = 'DISCOVER'.codeUnits;
      socket.send(discoveryMessage, InternetAddress(host), port);
      debugPrint('Sent test discovery message to $host:$port');

      // Listen for a response for 5 seconds
      String result = 'No response received';
      final completer = Completer<String>();

      late StreamSubscription subscription;
      subscription = socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket.receive();
          if (datagram != null) {
            final response = String.fromCharCodes(datagram.data);
            debugPrint('Test received response: $response');
            if (!completer.isCompleted) {
              completer.complete(
                'Received: $response from ${datagram.address}:${datagram.port}',
              );
            }
          }
        }
      });

      try {
        result = await completer.future.timeout(Duration(seconds: 5));
      } catch (e) {
        result = 'Timeout: No response within 5 seconds';
      }

      subscription.cancel();
      socket.close();

      return result;
    } catch (e) {
      return 'Error: $e';
    }
  }
}
