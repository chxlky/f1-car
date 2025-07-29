import 'package:cockpit/utils/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:cockpit/services/f1_discovery_service.dart';

class F1AppBar extends StatelessWidget implements PreferredSizeWidget {
  const F1AppBar({super.key});

  static final _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 3,
      lineLength: 80,
      colors: true,
      printEmojis: false,
    ),
  );

  static DateTime? _lastPressed;
  static const Duration _debounceTime = Duration(milliseconds: 1000);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      toolbarHeight: kToolbarHeight,
      flexibleSpace: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  SvgPicture.asset(
                    'assets/svg/f175.svg',
                    height: 32,
                    width: 100,
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(
                  LucideIcons.refreshCcw,
                  color: AppColors.white,
                ),
                padding: const EdgeInsets.all(8),
                splashRadius: 24,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.transparent,
                ),
                onPressed: () {
                  final now = DateTime.now();
                  if (_lastPressed != null &&
                      now.difference(_lastPressed!) < _debounceTime) {
                    _logger.w('Refresh button pressed too quickly - ignoring');
                    Fluttertoast.showToast(
                      msg: "Please wait before refreshing again",
                      toastLength: Toast.LENGTH_SHORT,
                      gravity: ToastGravity.BOTTOM,
                      textColor: Colors.white,
                      fontSize: 16.0,
                    );
                    return;
                  }
                  _lastPressed = now;

                  HapticFeedback.mediumImpact();
                  _logger.d(
                    'Refresh button clicked - starting F1 car discovery',
                  );

                  final discoveryService = context.read<F1DiscoveryService>();
                  discoveryService.startDiscovery();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
