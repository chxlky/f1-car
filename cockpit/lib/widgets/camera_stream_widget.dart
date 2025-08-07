import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cockpit/services/camera_stream_service.dart';
import 'package:cockpit/utils/app_colors.dart';

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

  void _connectToCamera() {
    if (widget.carIpAddress == null) return;

    final cameraService = context.read<CameraStreamService>();
    cameraService.connect(widget.carIpAddress!);
  }

  void _disconnectCamera() {
    final cameraService = context.read<CameraStreamService>();
    cameraService.disconnect();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CameraStreamService>(
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

  Widget _buildHeader(CameraStreamService cameraService) {
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
          Icon(Icons.videocam, color: AppColors.white, size: 20),
          const SizedBox(width: 8),
          Text(
            'Camera Stream',
            style: TextStyle(
              color: AppColors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const Spacer(),
          _buildConnectionButton(cameraService),
        ],
      ),
    );
  }

  Widget _buildConnectionButton(CameraStreamService cameraService) {
    switch (cameraService.connectionState) {
      case CameraConnectionState.disconnected:
        return ElevatedButton.icon(
          onPressed: widget.carIpAddress != null ? _connectToCamera : null,
          icon: const Icon(Icons.play_arrow, size: 16),
          label: const Text('Connect'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            minimumSize: const Size(80, 32),
          ),
        );

      case CameraConnectionState.connecting:
        return const SizedBox(
          width: 80,
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
        return ElevatedButton.icon(
          onPressed: _disconnectCamera,
          icon: const Icon(Icons.stop, size: 16),
          label: const Text('Stop'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            minimumSize: const Size(80, 32),
          ),
        );

      case CameraConnectionState.error:
        return ElevatedButton.icon(
          onPressed: widget.carIpAddress != null ? _connectToCamera : null,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Retry'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            minimumSize: const Size(80, 32),
          ),
        );
    }
  }

  Widget _buildCameraView(CameraStreamService cameraService) {
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

  Widget _buildVideoStream(CameraStreamService cameraService) {
    return StreamBuilder<Uint8List>(
      stream: cameraService.frameStream,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                snapshot.data!,
                fit: BoxFit.cover,
                gaplessPlayback: true, // Smooth frame transitions
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
          // Show latest frame while waiting for new ones
          return Container(
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

  Widget _buildFooter(CameraStreamService cameraService) {
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
          Icon(Icons.fiber_manual_record, color: Colors.red, size: 12),
          const SizedBox(width: 4),
          const Text(
            'LIVE',
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
