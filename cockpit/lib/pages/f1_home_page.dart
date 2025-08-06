import 'dart:async';

import 'package:cockpit/pages/radio_communication_page.dart';
import 'package:cockpit/src/rust/api/discovery.dart';
import 'package:cockpit/src/rust/api/models.dart';
import 'package:cockpit/widgets/car_card.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

enum ConnectionStatus { connected, disconnected, connecting }

class F1HomePage extends StatefulWidget {
  const F1HomePage({super.key});

  @override
  State<F1HomePage> createState() => F1HomePageState();
}

class F1HomePageState extends State<F1HomePage> {
  F1Car? _selectedCar;
  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;

  late final F1DiscoveryService _discoveryService;
  StreamSubscription<DiscoveryEvent>? _discoverySubscription;
  final List<F1Car> _discoveredCars = [];
  bool _isDiscovering = false;
  bool _isLoading = false;

  static final _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 80,
      colors: true,
      printEmojis: false,
    ),
  );

  @override
  void initState() {
    super.initState();
    _initializeDiscovery();
  }

  void refreshDiscovery() {
    _startDiscovery();
    // _loadMockCars();
  }

  @override
  void dispose() {
    // Cancel the stream subscription to avoid memory leaks
    _discoverySubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeDiscovery() async {
    setState(() => _isLoading = true);
    try {
      _discoveryService = F1DiscoveryService();
      // await _loadMockCars();
      await _startDiscovery();
    } catch (e) {
      _logger.e('Failed to initialize discovery: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _startDiscovery() async {
    if (_isDiscovering) return;

    await _discoverySubscription?.cancel();
    setState(() {
      _discoveredCars.clear();
    });

    try {
      final stream = _discoveryService.startDiscovery();
      _listenToDiscoveryStream(stream);
    } catch (e) {
      _logger.e('Failed to start discovery: $e');
    }
  }

  // ignore: unused_element
  Future<void> _loadMockCars() async {
    if (_isDiscovering) return;

    await _discoverySubscription?.cancel();
    setState(() {
      _discoveredCars.clear();
    });

    try {
      final stream = _discoveryService.loadMockCars();
      _listenToDiscoveryStream(stream);
    } catch (e) {
      _logger.e('Failed to load mock cars: $e');
    }
  }

  void _listenToDiscoveryStream(Stream<DiscoveryEvent> stream) {
    _discoverySubscription = stream.listen(
      (event) {
        if (!mounted) return;

        setState(() {
          event.when(
            discoveryStarted: () {
              _isDiscovering = true;
              _logger.i("Discovery started...");
            },
            discoveryStopped: () {
              _isDiscovering = false;
              _logger.i("Discovery stopped.");
            },
            carDiscovered: (car) {
              _discoveredCars.add(car);
              _logger.i(
                "Discovered car: (${car.number}) ${car.driverName} - ${car.teamName}",
              );
            },
            carUpdated: (car) {
              final index = _discoveredCars.indexWhere(
                (c) => c.number == car.number,
              );
              if (index != -1) {
                _discoveredCars[index] = car;
                _logger.i(
                  "Updated car: (${car.number}) ${car.driverName} - ${car.teamName}",
                );
              }
            },
            error: (message) {
              _isDiscovering = false;
              _logger.e("Discovery error: $message");
            },
          );
        });
      },
      onError: (e) {
        if (mounted) {
          setState(() => _isDiscovering = false);
        }
        _logger.e('Error in discovery stream: $e');
      },
      onDone: () {
        if (mounted) {
          setState(() => _isDiscovering = false);
        }
      },
    );
  }

  void _connectToCar(F1Car car) async {
    setState(() {
      _connectionStatus = ConnectionStatus.connecting;
      _selectedCar = car;
    });

    _logger.i(
      'Attempting to connect to car ${car.number} at ${car.ipAddress}:${car.port}',
    );

    if (mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => RadioCommunicationPage(car: car),
        ),
      );

      // Reset connection status when returning from radio page
      setState(() {
        _connectionStatus = ConnectionStatus.disconnected;
        _selectedCar = null;
      });
    }
  }

  Widget _buildCarList() {
    if (_discoveredCars.isEmpty) {
      return _buildNoCarsFound();
    } else {
      return _buildCarGrid();
    }
  }

  Widget _buildNoCarsFound() {
    final textTheme = Theme.of(context).textTheme;
    String message;
    if (_isDiscovering) {
      message = "Scanning for cars on the network...";
    } else if (_isLoading) {
      message = "Initializing discovery service...";
    } else {
      message = "No F1 cars were found on your network.";
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_isLoading || _isDiscovering)
            const Icon(LucideIcons.loaderCircle, size: 48) // TODO: Rotation
          else
            Text(message, style: textTheme.bodyLarge),
        ],
      ),
    );
  }

  Widget _buildCarGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 1,
        mainAxisSpacing: 24,
        crossAxisSpacing: 24,
        childAspectRatio: 2,
      ),
      itemCount: _discoveredCars.length,
      itemBuilder: (context, index) {
        final car = _discoveredCars[index];
        final isSelected =
            _selectedCar?.number == car.number &&
            _connectionStatus == ConnectionStatus.connected;
        final isConnecting =
            _selectedCar?.number == car.number &&
            _connectionStatus == ConnectionStatus.connecting;

        return CarCard(
          car: car,
          onConnect: _connectToCar,
          isSelected: isSelected,
          isConnecting: isConnecting,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      clipBehavior: Clip.hardEdge,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'DISCOVER CARS',
              textAlign: TextAlign.center,
              style: textTheme.displayLarge,
            ),
            Transform.translate(
              offset: const Offset(0, -50),
              child: _buildCarList(),
            ),
          ],
        ),
      ),
    );
  }
}
