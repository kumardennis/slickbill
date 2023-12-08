import 'package:flutter/material.dart';

extension CustomColorScheme on ColorScheme {
  Color get lightYellow => const Color(0xFFF1D7A5);
  Color get yellow => const Color(0xFFFFD645);
  Color get blue => const Color(0xFF2C8A9E);
  Color get lightGreen => const Color(0xFFA1CDAF);
  Color get green => const Color(0xFF399E5A);
  Color get red => const Color(0xFFDB2B39);
  Color get light => const Color(0xFFF3F9FA);
  Color get dark => const Color(0xFF0A0B0C);
  Color get gray => const Color(0xFF979797);
  Color get darkGray => const Color(0xFF1F2124);
}

Map customColorScheme = {
  'lightYellow': const Color(0xFFF1D7A5),
  'yellow': const Color(0xFFFFD645),
  'blue': const Color(0xFF2C8A9E),
  'lightGreen': const Color(0xFFA1CDAF),
  'green': const Color(0xFF399E5A),
  'red': const Color(0xFFDB2B39),
  'light': const Color(0xFFF3F9FA),
  'dark': const Color(0xFF0A0B0C),
  'gray': const Color(0xFF979797),
  'darkGray': const Color(0xFF1F2124),
};
