import 'package:flutter/material.dart';

extension CustomColorScheme on ColorScheme {
  Color get lightYellow => const Color(0xFFF1D7A5);
  Color get yellow => const Color(0xFFE4C142);
  Color get blue => const Color(0xFF003453);
  Color get lighterBlue => const Color(0xFF0074B9);
  Color get darkerBlue => const Color(0xFF003453);
  Color get lightGreen => const Color(0xFFA1CDAF);
  Color get darkGreen => Color.fromARGB(255, 46, 19, 78);
  Color get turqouise => const Color.fromARGB(255, 1, 56, 73);
  Color get green => const Color(0xFF399E5A);
  Color get red => const Color(0xFFDB2B39);
  Color get light => const Color(0xFFF3F9FA);
  Color get dark => const Color(0xFF0A0B0C);
  Color get gray => const Color(0xFF979797);
  Color get lightGray => const Color(0xFFBFBFBF);
  Color get darkGray => const Color(0xFF1F2124);
}

Map customColorScheme = {
  'lightYellow': const Color(0xFFF1D7A5),
  'yellow': const Color(0xFFE4C142),
  'blue': const Color(0xFF003453),
  'lighterBlue': const Color(0xFF0074B9),
  'darkerBlue': const Color(0xFF003453),
  'lightGreen': const Color(0xFFA1CDAF),
  'darkGreen': Color.fromARGB(255, 46, 19, 78),
  'turqouise': Color.fromARGB(255, 1, 56, 73),
  'green': const Color(0xFF399E5A),
  'red': const Color(0xFFDB2B39),
  'light': const Color(0xFFF3F9FA),
  'dark': const Color(0xFF0A0B0C),
  'gray': const Color(0xFF979797),
  'lightGray': const Color(0xFFBFBFBF),
  'darkGray': const Color(0xFF1F2124),
};
