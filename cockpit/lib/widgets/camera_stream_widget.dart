import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cockpit/utils/app_colors.dart';
import 'package:cockpit/services/udp_camera_service.dart';

class CameraStreamWidget extends StatefulWidget {
  final String? carIpAddress;
  final bool autoConnect;

  const CameraStreamWidget({
    super.key,
    this.carIpAddress,
    this.autoConnect = false,
  });

  @override
  State<CameraStreamWidget> createState() => _CameraStreamWidgetState();
}

class _CameraStreamWidgetState extends State<CameraStreamWidget> {
  @override
  void initState() {
    super.initState();

    if (widget.autoConnect && widget.carIpAddress != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _connectToCamera();
      });
    }
  }

  @override
  void dispose() {
    // Automatically disconnect when the widget is disposed (user goes back)
    final cameraService = context.read<UdpCameraService>();
    if (cameraService.connectionState == CameraConnectionState.connected) {
      cameraService.stopCamera().then((_) {
        cameraService.disconnect();
      });
    }
    super.dispose();
  }

  void _connectToCamera() {
    if (widget.carIpAddress == null) return;

    final cameraService = context.read<UdpCameraService>();
    cameraService.connect(widget.carIpAddress!).then((success) {
      if (success) {
        // Don't auto-start camera streaming anymore
        // Let the user explicitly start it
        debugPrint('Connected to camera server - camera ready to start');
      }
    });
  }

  void _startCameraStreaming() {
    final cameraService = context.read<UdpCameraService>();
    cameraService.startCamera();
  }

  void _stopCameraStreaming() {
    final cameraService = context.read<UdpCameraService>();
    cameraService.stopCamera();
  }

  Widget _buildHeader(UdpCameraService cameraService) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: AppColors.f1Red,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(10),
          topRight: Radius.circular(10),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.videocam, color: AppColors.white, size: 20),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Camera Stream',
              style: TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          _buildMainButton(cameraService),
        ],
      ),
    );
  }

  Widget _buildMainButton(UdpCameraService cameraService) {
    switch (cameraService.connectionState) {
      case CameraConnectionState.disconnected:
        return ElevatedButton.icon(
          onPressed: widget.carIpAddress != null ? _connectToCamera : null,
          icon: const Icon(Icons.wifi, size: 16),
          label: const Text('Connect'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            minimumSize: const Size(90, 32),
          ),
        );

      case CameraConnectionState.connecting:
        return const SizedBox(
          width: 90,
          height: 32,
          child: Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ),
        );

      case CameraConnectionState.connected:
        if (cameraService.isCameraStreaming) {
          return ElevatedButton.icon(
            onPressed: _stopCameraStreaming,
            icon: const Icon(Icons.stop, size: 16),
            label: const Text('Stop'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              minimumSize: const Size(90, 32),
            ),
          );
        } else {
          return ElevatedButton.icon(
            onPressed: _startCameraStreaming,
            icon: const Icon(Icons.play_arrow, size: 16),
            label: const Text('Start'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              minimumSize: const Size(90, 32),
            ),
          );
        }

      case CameraConnectionState.error:
        return ElevatedButton.icon(
          onPressed: widget.carIpAddress != null ? _connectToCamera : null,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Retry'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            minimumSize: const Size(90, 32),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UdpCameraService>(
      builder: (context, cameraService, child) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.f1Dark,
            border: Border.all(color: AppColors.f1Red, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              // Header with connection controls
              _buildHeader(cameraService),

              // Camera view
              Expanded(child: _buildCameraView(cameraService)),

              // Footer with stats
              _buildFooter(cameraService),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCameraView(UdpCameraService cameraService) {
    switch (cameraService.connectionState) {
      case CameraConnectionState.disconnected:
        return _buildPlaceholder(
          icon: Icons.videocam_off,
          text: widget.carIpAddress != null
              ? 'Tap Connect to start camera stream'
              : 'No car selected',
        );

      case CameraConnectionState.connecting:
        return _buildPlaceholder(
          icon: Icons.videocam,
          text: 'Connecting to camera...',
          showProgress: true,
        );

      case CameraConnectionState.connected:
        if (!cameraService.isCameraStreaming) {
          return _buildPlaceholder(
            icon: Icons.videocam,
            text: 'Camera connected. Tap Start to begin streaming.',
          );
        }
        return _buildVideoStream(cameraService);

      case CameraConnectionState.error:
        return _buildPlaceholder(
          icon: Icons.error_outline,
          text: 'Camera Error: ${cameraService.lastError}',
          textColor: Colors.red,
        );
    }
  }

  Widget _buildPlaceholder({
    required IconData icon,
    required String text,
    Color? textColor,
    bool showProgress = false,
  }) {
    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 100),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: textColor ?? Colors.grey),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  text,
                  style: TextStyle(
                    color: textColor ?? Colors.grey,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (showProgress) ...[
                const SizedBox(height: 12),
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoStream(UdpCameraService cameraService) {
    if (!cameraService.isCameraStreaming) {
      return _buildPlaceholder(
        icon: Icons.videocam,
        text: 'Camera ready. Tap Start to begin streaming.',
      );
    }

    return StreamBuilder<Uint8List>(
      stream: cameraService.frameStream,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                snapshot.data!,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (context, error, stackTrace) {
                  return _buildPlaceholder(
                    icon: Icons.broken_image,
                    text: 'Failed to decode frame',
                    textColor: Colors.red,
                  );
                },
              ),
            ),
          );
        } else if (cameraService.latestFrame != null) {
          return SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                cameraService.latestFrame!,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),
          );
        } else {
          return _buildPlaceholder(
            icon: Icons.videocam,
            text: 'Waiting for first frame...',
            showProgress: true,
          );
        }
      },
    );
  }

  Widget _buildFooter(UdpCameraService cameraService) {
    if (cameraService.connectionState != CameraConnectionState.connected) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(10),
          bottomRight: Radius.circular(10),
        ),
      ),
      child: Row(
        children: [
          Icon(
            cameraService.isCameraStreaming
                ? Icons.fiber_manual_record
                : Icons.radio_button_unchecked,
            color: cameraService.isCameraStreaming ? Colors.red : Colors.grey,
            size: 12,
          ),
          const SizedBox(width: 4),
          Text(
            cameraService.isCameraStreaming ? 'LIVE' : 'READY',
            style: TextStyle(
              color: cameraService.isCameraStreaming ? Colors.red : Colors.grey,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const Spacer(),
          Text(
            cameraService.isCameraStreaming ? 'Streaming' : 'Stopped',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
