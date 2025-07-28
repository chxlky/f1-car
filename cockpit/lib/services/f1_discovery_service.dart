import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_nsd/flutter_nsd.dart';

class F1DiscoveryService extends ChangeNotifier {
  bool _isDiscovering = false;
  FlutterNsd? _flutterNsd;
  StreamSubscription<NsdServiceInfo>? _subscription;
  Timer? _timeoutTimer;

  bool get isDiscovering => _isDiscovering;

  void startDiscovery() async {
    print("Starting F1 car discovery...");

    if (_isDiscovering) {
      print("Discovery already in progress");
      return;
    }

    _isDiscovering = true;
    notifyListeners();

    try {
      await _performDiscovery();
    } catch (e) {
      print('Discovery error: $e');
    } finally {
      _isDiscovering = false;
      notifyListeners();
    }
  }

  Future<void> _performDiscovery() async {
    try {
      _flutterNsd = FlutterNsd();

      // Listen to the stream for discovered services
      _subscription = _flutterNsd!.stream.listen(
        (NsdServiceInfo serviceInfo) {
          print('Discovered F1 car service: ${serviceInfo.name}');
          if (serviceInfo.hostname != null && serviceInfo.port != null) {
            String address;
            if (serviceInfo.hostname!.contains(':')) {
              address = '[${serviceInfo.hostname}]:${serviceInfo.port}';
            } else {
              address = '${serviceInfo.hostname}:${serviceInfo.port}';
            }
            print('Service address: $address');
          } else {
            print('Service found but hostname/port not available');
          }
        },
        onError: (error) {
          print('Discovery error: $error');
        },
      );

      // Set a timeout
      _timeoutTimer = Timer(const Duration(seconds: 10), () {
        print('Discovery timeout - stopping');
        stopDiscovery();
      });

      // Start discovering the F1 car service
      // Note: On Android, the service name must end with a dot
      const serviceName = '_f1-car._udp.';
      print('Starting discovery for service: $serviceName');

      await _flutterNsd!.discoverServices(serviceName);

      print('Discovery started successfully');
    } catch (e) {
      print('Failed to start discovery: $e');
      rethrow;
    }
  }

  void stopDiscovery() async {
    if (!_isDiscovering) return;

    print("Stopping discovery...");

    _isDiscovering = false;
    _timeoutTimer?.cancel();

    try {
      await _subscription?.cancel();
      await _flutterNsd?.stopDiscovery();
      print("Discovery stopped");
    } catch (e) {
      print('Error stopping discovery: $e');
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
