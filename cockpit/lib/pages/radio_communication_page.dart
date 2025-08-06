import 'package:cockpit/services/radio_service.dart';
import 'package:cockpit/src/rust/api/models.dart';
import 'package:cockpit/utils/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class RadioCommunicationPage extends StatefulWidget {
  final F1Car car;

  const RadioCommunicationPage({super.key, required this.car});

  @override
  State<RadioCommunicationPage> createState() => _RadioCommunicationPageState();
}

class _RadioCommunicationPageState extends State<RadioCommunicationPage> {
  late RadioService _radioService;
  final List<String> _messages = [];
  final ScrollController _scrollController = ScrollController();

  double _steering = 0.0; // -100 to 100
  double _throttle = 0.0; // -100 to 100

  @override
  void initState() {
    super.initState();
    _radioService = context.read<RadioService>();
    _connectToCar();
    _listenToMessages();
  }

  void _connectToCar() async {
    // No need to call _addMessage here, the service will notify of connection state
    await _radioService.connect(widget.car);
  }

  void _listenToMessages() {
    _radioService.messageStream.listen((message) {
      if (!mounted) return;
      message.when(
        identity: (identity) => _addMessage(
          '📡 Car identity: #${identity.number} ${identity.driverName} (${identity.teamName})',
        ),
        physics: (physics) => _addMessage(
          '⚙️ Car physics: Max Steering=${physics.maxSteeringAngle}, Max Throttle=${physics.maxThrottle}',
        ),
        identityUpdated: (success, message) => _addMessage(
          '✅ Identity ${success ? 'updated' : 'failed'}: $message',
        ),
        physicsUpdated: (success, message) => _addMessage(
          '✅ Physics ${success ? 'updated' : 'failed'}: $message',
        ),
        pong: (timestamp) {
          final latency = DateTime.now().millisecondsSinceEpoch - timestamp;
          _addMessage('🏓 Pong received (${latency}ms)');
        },
        error: (message) => _addMessage('❌ Error: $message'),
      );
    });
  }

  void _addMessage(String message) {
    if (!mounted) return;
    setState(() {
      _messages.add(
        '[${DateTime.now().toLocal().toString().substring(11, 19)}] $message',
      );
    });

    // Auto-scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendControlMessage() {
    if (_radioService.connectionState == RadioConnectionState.connected) {
      _radioService.sendControl(
        steering: _steering.round(),
        throttle: _throttle.round(),
      );
      _addMessage(
        '🎮 Control sent: Steering ${_steering.round()}, Throttle ${_throttle.round()}',
      );
    }
  }

  Widget _buildConnectionStatus() {
    return Consumer<RadioService>(
      builder: (context, service, child) {
        final state = service.connectionState;
        Color statusColor;
        String statusText;
        IconData statusIcon;

        switch (state) {
          case RadioConnectionState.connected:
            statusColor = Colors.green;
            statusText = 'Connected';
            statusIcon = Icons.radio;
            _addMessage('✅ Connected to car ${widget.car.number}');
            break;
          case RadioConnectionState.connecting:
            statusColor = Colors.orange;
            statusText = 'Connecting...';
            statusIcon = Icons.sync;
            break;
          case RadioConnectionState.error:
            statusColor = Colors.red;
            statusText = 'Error';
            statusIcon = Icons.error;
            if (service.lastError != null) {
              _addMessage('❌ Failed to connect: ${service.lastError}');
            }
            break;
          case RadioConnectionState.disconnected:
            statusColor = Colors.grey;
            statusText = 'Disconnected';
            statusIcon = Icons.radio_button_off;
            _addMessage('🔌 Disconnected from car ${widget.car.number}');
            break;
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            border: Border.all(color: statusColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(statusIcon, color: statusColor, size: 16),
              const SizedBox(width: 8),
              Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCarInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Car #${widget.car.number}',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.car.driverName,
            style: const TextStyle(fontSize: 18, color: AppColors.white),
          ),
          Text(
            widget.car.teamName,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            '${widget.car.ipAddress}:${widget.car.port}',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Car Controls',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.white,
            ),
          ),
          const SizedBox(height: 16),

          // Steering control
          Text(
            'Steering: ${_steering.round()}',
            style: const TextStyle(color: AppColors.white),
          ),
          Slider(
            value: _steering,
            min: -100,
            max: 100,
            divisions: 200,
            onChanged: (value) {
              setState(() {
                _steering = value;
              });
            },
            onChangeEnd: (_) => _sendControlMessage(),
            activeColor: AppColors.f1Red,
            inactiveColor: Colors.grey,
          ),

          // Throttle control
          Text(
            'Throttle: ${_throttle.round()}',
            style: const TextStyle(color: AppColors.white),
          ),
          Slider(
            value: _throttle,
            min: -100,
            max: 100,
            divisions: 200,
            onChanged: (value) {
              setState(() {
                _throttle = value;
              });
            },
            onChangeEnd: (_) => _sendControlMessage(),
            activeColor: AppColors.f1Red,
            inactiveColor: Colors.grey,
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Radio Communication',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.white,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    _messages[index],
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.f1Dark,
      appBar: AppBar(
        title: Text('Radio - Car #${widget.car.number}'),
        backgroundColor: AppColors.f1Dark,
        foregroundColor: AppColors.white,
        actions: [_buildConnectionStatus(), const SizedBox(width: 16)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCarInfo(),
            const SizedBox(height: 16),
            _buildControlPanel(),
            const SizedBox(height: 16),
            _buildMessagesList(),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _radioService.disconnect();
    _scrollController.dispose();
    super.dispose();
  }
}
