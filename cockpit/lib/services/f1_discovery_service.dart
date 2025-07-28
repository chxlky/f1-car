import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_nsd/flutter_nsd.dart';
import 'package:logger/logger.dart';
import 'package:cockpit/models/f1car.dart';

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
  List<F1Car> _discoveredCars = [];

  bool get isDiscovering => _isDiscovering;
  List<F1Car> get discoveredCars => List.unmodifiable(_discoveredCars);

  void startDiscovery() async {
    _logger.i("Starting F1 car discovery...");

    if (_isDiscovering) {
      _logger.w(
        "Discovery already in progress - stopping current discovery first",
      );
      await _stopDiscovery();
      await Future.delayed(const Duration(milliseconds: 100));
    }

    await _ensureCleanState();
    _discoveredCars.clear();

    _isDiscovering = true;
    notifyListeners();

    try {
      await _performDiscovery();
    } catch (e) {
      _logger.e('Discovery error: $e');
      await _ensureCleanState();
    } finally {
      _isDiscovering = false;
      notifyListeners();
    }
  }

  Future<void> _ensureCleanState() async {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;

    try {
      await _subscription?.cancel();
    } catch (e) {
      _logger.w('Error canceling subscription: $e');
    }
    _subscription = null;

    try {
      if (_flutterNsd != null) {
        await _flutterNsd!.stopDiscovery();
        await Future.delayed(const Duration(milliseconds: 50));
      }
    } catch (e) {
      _logger.w('Error stopping FlutterNsd: $e');
    }
    _flutterNsd = null;
  }

  Future<void> _performDiscovery() async {
    try {
      _flutterNsd = FlutterNsd();

      _subscription = _flutterNsd!.stream.listen(
        (NsdServiceInfo serviceInfo) {
          _logger.i('Discovered F1 car service: ${serviceInfo.name}');

          String? carNumberStr;
          String? driverName;
          String? teamName;
          String? version;

          if (serviceInfo.txt != null && serviceInfo.txt!.isNotEmpty) {
            carNumberStr = _extractCarValue(serviceInfo.txt!, 'number');
            driverName = _extractCarValue(serviceInfo.txt!, 'driver');
            teamName = _extractCarValue(serviceInfo.txt!, 'team');
            version = _extractCarValue(serviceInfo.txt!, 'version');
          } else {
            _logger.w('No TXT records found for service');
          }

          if (carNumberStr != null &&
              driverName != null &&
              teamName != null &&
              version != null) {
            final carNumber = int.tryParse(carNumberStr) ?? 0;

            final f1Car = F1Car(
              number: carNumber,
              driverName: driverName,
              teamName: teamName,
              version: version,
            );

            final existingIndex = _discoveredCars.indexWhere(
              (car) => car.number == f1Car.number,
            );

            if (existingIndex != -1) {
              _discoveredCars[existingIndex] = f1Car;
              _logger.d('Updated existing F1 car #${f1Car.number}');
            } else {
              _discoveredCars.add(f1Car);
              _logger.i(
                'Added F1 car #${f1Car.number} (${f1Car.driverName} - ${f1Car.teamName})',
              );
            }

            notifyListeners();
          } else {
            _logger.w(
              'Incomplete F1 car data - missing required fields (number: $carNumberStr, driver: $driverName, team: $teamName, version: $version)',
            );
          }
        },
        onError: (error) {
          if (error is NsdError) {
            _logger.e(
              'Discovery NSD error - Code: ${error.errorCode}, Details: $error',
            );
            _stopDiscovery();
          } else {
            _logger.e('Discovery stream error: $error');
          }
        },
      );

      _timeoutTimer = Timer(const Duration(seconds: 10), () {
        _logger.i(
          'Discovery timeout - found ${_discoveredCars.length} F1 car(s)',
        );
        _stopDiscovery();
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

  String? _extractCarValue(Map<String, List<int>> txtRecords, String key) {
    final value = txtRecords[key];
    return value != null ? String.fromCharCodes(value) : null;
  }

  Future<void> stopDiscovery() async {
    await _stopDiscovery();
  }

  Future<void> _stopDiscovery() async {
    if (!_isDiscovering) return;

    _logger.i("Discovery stopped - found ${_discoveredCars.length} F1 car(s)");

    _isDiscovering = false;

    await _ensureCleanState();

    notifyListeners();
  }

  @override
  void dispose() {
    stopDiscovery();
    super.dispose();
  }
}
