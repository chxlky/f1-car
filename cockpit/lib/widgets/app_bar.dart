import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:cockpit/services/f1_discovery_service.dart';

class F1AppBar extends StatelessWidget implements PreferredSizeWidget {
  const F1AppBar({super.key});

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
                icon: const Icon(Icons.refresh, color: Colors.white),
                padding: const EdgeInsets.all(8),
                splashRadius: 24,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.transparent,
                ),
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  print("Refresh clicked");

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
