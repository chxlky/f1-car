import 'package:cockpit/utils/app_colors.dart';
import 'package:flutter/material.dart';

class AppTypography {
  static TextTheme buildTextTheme(TextTheme base) {
    return base.copyWith(
      displayLarge: const TextStyle(
        fontFamily: 'Formula1',
        fontSize: 40,
        fontWeight: FontWeight.w700,
        color: AppColors.white,
      ),
      headlineMedium: const TextStyle(
        fontFamily: 'Northwell-Alt',
        fontSize: 32,
        fontWeight: FontWeight.w300,
        fontStyle: FontStyle.italic,
        color: AppColors.white,
      ),
      headlineSmall: const TextStyle(
        fontFamily: 'KHInterference',
        fontSize: 50,
        fontWeight: FontWeight.w400,
        color: Color.fromRGBO(255, 255, 255, 0.8),
      ),
      bodyLarge: const TextStyle(
        fontFamily: 'Formula1',
        fontSize: 16,
        color: AppColors.white,
      ),
    );
  }
}
