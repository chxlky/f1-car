import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_nsd/flutter_nsd.dart';
import 'package:logger/logger.dart';
import 'package:cockpit/models/f1car.dart';

class F1DiscoveryService extends ChangeNotifier {
  static const _serviceType = '_f1-car._udp.';
  static const _discoveryTimeout = Duration(seconds: 10);

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
  final List<F1Car> _discoveredCars = [];

  bool get isDiscovering => _isDiscovering;
  List<F1Car> get discoveredCars => List.unmodifiable(_discoveredCars);

  Future<void> startDiscovery() async {
    _logger.i('Starting F1 car discovery...');

    if (_isDiscovering) {
      _logger.w(
        'Discovery already in progress - stopping current discovery first',
      );
      await stopDiscovery();
      await Future.delayed(const Duration(milliseconds: 100));
    }

    _discoveredCars.clear();
    _isDiscovering = true;
    notifyListeners();

    try {
      // await _loadMockCars();
      await _performDiscovery();
    } catch (e) {
      _logger.e('Discovery error: $e');
      await stopDiscovery();
    }
  }

  Future<void> stopDiscovery() async {
    if (!_isDiscovering) return;

    _logger.i(
      'Stopping discovery - found ${_discoveredCars.length} F1 car(s).',
    );

    _isDiscovering = false;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;

    try {
      await _subscription?.cancel();
    } catch (e) {
      _logger.w('Error cancelling subscription: $e');
    }
    _subscription = null;

    try {
      if (_flutterNsd != null) {
        await _flutterNsd!.stopDiscovery();
      }
    } catch (e) {
      _logger.w('Error stopping FlutterNsd discovery: $e');
    }
    _flutterNsd = null;

    notifyListeners();
  }

  @override
  void dispose() {
    stopDiscovery();
    super.dispose();
  }

  // ignore: unused_element
  Future<void> _loadMockCars() async {
    _logger.i('Loading mock F1 cars...');

    // Simulate some discovery delay
    await Future.delayed(const Duration(milliseconds: 500));

    final mockCars = [
      F1Car(
        number: 1,
        driverName: 'Max Verstappen',
        teamName: 'Oracle Red Bull Racing',
        version: '1.0.0',
      ),
      F1Car(
        number: 16,
        driverName: 'Charles Leclerc',
        teamName: 'Scuderia Ferrari HP',
        version: '1.0.2',
      ),
      F1Car(
        number: 55,
        driverName: 'Carlos Sainz',
        teamName: 'Atlassian Williams Racing',
        version: '1.0.2',
      ),
      F1Car(
        number: 27,
        driverName: 'Nico Hülkenberg',
        teamName: 'Stake F1 Team Kick Sauber',
        version: '1.0.2',
      ),
    ];

    for (final car in mockCars) {
      _discoveredCars.add(car);
      _logger.i(
        'Added mock F1 car #${car.number} (${car.driverName} - ${car.teamName})',
      );

      await Future.delayed(const Duration(milliseconds: 200));
      notifyListeners();
    }

    _logger.i(
      'Mock discovery completed. Found ${_discoveredCars.length} cars.',
    );
    await stopDiscovery();
  }

  Future<void> _performDiscovery() async {
    try {
      _flutterNsd = FlutterNsd();
      _subscription = _flutterNsd!.stream.listen(
        _onServiceDiscovered,
        onError: _onDiscoveryError,
        onDone: () {
          _logger.i('Discovery stream closed.');
          stopDiscovery();
        },
      );

      await _flutterNsd!.discoverServices(_serviceType);
      _logger.i('Discovery started for service type: $_serviceType');

      _timeoutTimer = Timer(_discoveryTimeout, () {
        _logger.i(
          'Discovery timeout reached after ${_discoveryTimeout.inSeconds} seconds. Found ${_discoveredCars.length} car(s).',
        );
        stopDiscovery();
      });
    } catch (e) {
      _logger.e('Failed to start discovery: $e');
      rethrow;
    }
  }

  void _onServiceDiscovered(NsdServiceInfo serviceInfo) {
    _logger.i('Discovered service: ${serviceInfo.name}');

    final data = serviceInfo.txt;
    if (data == null || data.isEmpty) {
      _logger.w('Service has no records, skipping.');
      return;
    }

    try {
      final car = _createCarFromData(data);
      _addOrUpdateCar(car);
      notifyListeners();
    } catch (e) {
      _logger.w('Failed to create F1Car from records: $e');
    }
  }

  F1Car _createCarFromData(Map<String, List<int>> data) {
    final carNumberStr = _extractCarValue(data, 'number');
    final driverName = _extractCarValue(data, 'driver');
    final teamName = _extractCarValue(data, 'team');
    final version = _extractCarValue(data, 'version');

    final carNumber = int.tryParse(carNumberStr);
    if (carNumber == null) {
      throw Exception('Invalid car number: $carNumberStr');
    }

    return F1Car(
      number: carNumber,
      driverName: driverName,
      teamName: teamName,
      version: version,
    );
  }

  void _addOrUpdateCar(F1Car car) {
    final existingIndex = _discoveredCars.indexWhere(
      (c) => c.number == car.number,
    );

    if (existingIndex != -1) {
      _discoveredCars[existingIndex] = car;
      _logger.d('Updated existing F1 car #${car.number}');
    } else {
      _discoveredCars.add(car);
      _logger.i(
        'Added new F1 car #${car.number} (${car.driverName} - ${car.teamName})',
      );
    }
  }

  void _onDiscoveryError(dynamic error) {
    if (error is NsdError) {
      _logger.e(
        'Discovery NSD error - Code: ${error.errorCode}, Details: $error',
      );
    } else {
      _logger.e('Discovery stream error: $error');
    }
    stopDiscovery();
  }

  String _extractCarValue(Map<String, List<int>> records, String key) {
    final value = records[key];
    if (value == null) {
      throw Exception('Missing required record: $key');
    }

    return String.fromCharCodes(value);
  }
}
