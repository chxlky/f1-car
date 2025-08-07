import 'package:cockpit/pages/f1_home_page.dart';
import 'package:cockpit/utils/app_colors.dart';
import 'package:cockpit/utils/app_typography.dart';
import 'package:cockpit/utils/assets_path.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:cockpit/widgets/app_bar.dart';
import 'package:cockpit/services/f1_discovery_service.dart';
import 'package:cockpit/services/udp_camera_service.dart';

void main() {
  runApp(const F1App());
}

class F1App extends StatelessWidget {
  const F1App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => F1DiscoveryService()),
        ChangeNotifierProvider(create: (context) => UdpCameraService()),
      ],
      child: MaterialApp(
        title: 'Cockpit',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: AppColors.f1Dark,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            iconTheme: IconThemeData(color: AppColors.white),
          ),
          textTheme: AppTypography.buildTextTheme(ThemeData.dark().textTheme),
          useMaterial3: true,
        ),
        home: const MainLayoutWrapper(),
      ),
    );
  }
}

class MainLayoutWrapper extends StatelessWidget {
  const MainLayoutWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    const appBar = F1AppBar();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: appBar,
      body: SizedBox(
        height: mediaQuery.size.height,
        width: mediaQuery.size.width,
        child: Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: 0.2,
                child: SvgPicture.asset(
                  AssetsPath.f1LinesSvg,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Positioned(
              top: appBar.preferredSize.height + mediaQuery.padding.top,
              left: 0,
              right: 0,
              bottom: 0,
              child: ClipRect(child: const F1HomePage()),
            ),
          ],
        ),
      ),
    );
  }
}
