import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_nsd/flutter_nsd.dart';
import 'package:logger/logger.dart';

// TODO: Fix error that happens when refresh is pressed twice
class F1DiscoveryService extends ChangeNotifier {
  static final _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 80,
      colors: true,
      printEmojis: false,
    ),
  );

  bool _isDiscovering = false;
  FlutterNsd? _flutterNsd;
  StreamSubscription<NsdServiceInfo>? _subscription;
  Timer? _timeoutTimer;

  bool get isDiscovering => _isDiscovering;

  void startDiscovery() async {
    _logger.i("Starting F1 car discovery...");

    if (_isDiscovering) {
      _logger.w("Discovery already in progress");
      return;
    }

    _isDiscovering = true;
    notifyListeners();

    try {
      await _performDiscovery();
    } catch (e) {
      _logger.e('Discovery error: $e');
    } finally {
      _isDiscovering = false;
      notifyListeners();
    }
  }

  Future<void> _performDiscovery() async {
    try {
      _flutterNsd = FlutterNsd();

      _subscription = _flutterNsd!.stream.listen(
        (NsdServiceInfo serviceInfo) {
          _logger.i('Discovered F1 car service: ${serviceInfo.name}');
          if (serviceInfo.hostname != null && serviceInfo.port != null) {
            String address;
            if (serviceInfo.hostname!.contains(':')) {
              address = '[${serviceInfo.hostname}]:${serviceInfo.port}';
            } else {
              address = '${serviceInfo.hostname}:${serviceInfo.port}';
            }
            _logger.d('Service address: $address');
          } else {
            _logger.w('Service found but hostname/port not available');
          }
        },
        onError: (error) {
          _logger.e('Discovery stream error: $error');
        },
      );

      _timeoutTimer = Timer(const Duration(seconds: 10), () {
        _logger.w('Discovery timeout - stopping');
        stopDiscovery();
      });

      const serviceName = '_f1-car._udp.';
      _logger.d('Starting discovery for service: $serviceName');

      await _flutterNsd!.discoverServices(serviceName);

      _logger.i('Discovery started successfully');
    } catch (e) {
      _logger.e('Failed to start discovery: $e');
      rethrow;
    }
  }

  void stopDiscovery() async {
    if (!_isDiscovering) return;

    _logger.d("Stopping discovery...");

    _isDiscovering = false;
    _timeoutTimer?.cancel();

    try {
      await _subscription?.cancel();
      await _flutterNsd?.stopDiscovery();
      _logger.i("Discovery stopped");
    } catch (e) {
      _logger.e('Error stopping discovery: $e');
    }

    _subscription = null;
    _flutterNsd = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stopDiscovery();
    super.dispose();
  }
}
