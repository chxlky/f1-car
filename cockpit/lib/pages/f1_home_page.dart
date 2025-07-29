import 'package:cockpit/models/f1car.dart';
import 'package:cockpit/services/f1_discovery_service.dart';
import 'package:cockpit/widgets/car_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

enum ConnectionStatus { connected, disconnected, connecting }

class F1HomePage extends StatefulWidget {
  const F1HomePage({super.key});

  @override
  State<F1HomePage> createState() => _F1HomePageState();
}

class _F1HomePageState extends State<F1HomePage> {
  F1Car? _selectedCar;
  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final discoveryService = Provider.of<F1DiscoveryService>(
        context,
        listen: false,
      );
      if (!discoveryService.isDiscovering) {
        discoveryService.startDiscovery();
      }
    });
  }

  void _connectToCar(F1Car car) {
    setState(() {
      _connectionStatus = ConnectionStatus.connecting;
      _selectedCar = car;
    });

    // TODO: Implement actual connection logic here
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _connectionStatus = ConnectionStatus.connected;
        });

        HapticFeedback.mediumImpact();

        _logger.i('Connected to car ${car.number}');
      }
    });
  }

  Widget _buildCarList(F1DiscoveryService discoveryService) {
    if (discoveryService.discoveredCars.isEmpty) {
      return _buildNoCarsFound(discoveryService);
    } else {
      return _buildCarGrid(discoveryService);
    }
  }

  Widget _buildNoCarsFound(F1DiscoveryService discoveryService) {
    final textTheme = Theme.of(context).textTheme;
    String message;
    if (discoveryService.isDiscovering) {
      message = "Scanning for cars on the network...";
    } else {
      message = "Start discovery to find F1 cars on your network";
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🏎️', style: TextStyle(fontSize: 60)),
          const SizedBox(height: 16),
          Text(
            'No F1 Cars Discovered',
            style: textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildCarGrid(F1DiscoveryService discoveryService) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 1,
        mainAxisSpacing: 24,
        crossAxisSpacing: 24,
        childAspectRatio: 2,
      ),
      itemCount: discoveryService.discoveredCars.length,
      itemBuilder: (context, index) {
        final car = discoveryService.discoveredCars[index];
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

    return Consumer<F1DiscoveryService>(
      builder: (context, discoveryService, child) {
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
                  child: _buildCarList(discoveryService),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
