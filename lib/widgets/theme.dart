import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,

    scaffoldBackgroundColor: const Color(0xFF1F1F39),

    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF3D5CFF),
      secondary: Color(0xFF18193C),
      surface: Color(0xFF161632),
      onSurface: Colors.white,
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xFF3D5CFF),
      elevation: 0,
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      iconTheme: const IconThemeData(color: Colors.white),
    ),

    drawerTheme: const DrawerThemeData(backgroundColor: Color(0xFF1F1F39)),
    textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
    iconTheme: const IconThemeData(color: Colors.white),
  );

  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    useMaterial3: true,

    scaffoldBackgroundColor: const Color(0xFFF7F9FC),

    colorScheme: const ColorScheme.light(
      primary: Color(0xFF3D5CFF),
      secondary: Color(0xFFE6F2FF),
      surface: Colors.white,
      onSurface: Color(0xFF1F1F39),
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xFF3D5CFF),
      elevation: 0,
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      iconTheme: const IconThemeData(color: Colors.white),
    ),

    drawerTheme: const DrawerThemeData(backgroundColor: Colors.white),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: const Color(0xFFCDEBFD),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: Color(0xFF3D5CFF));
        }
        return const IconThemeData(color: Color.fromRGBO(31, 31, 57, 0.6));
      }),
      labelTextStyle: WidgetStateProperty.all(
        GoogleFonts.poppins(color: const Color(0xFF1F1F39)),
      ),
    ),

    textTheme: GoogleFonts.poppinsTextTheme(
      ThemeData.light().textTheme.copyWith(
        bodyLarge: const TextStyle(color: Color(0xFF1F1F39)),
        bodyMedium: const TextStyle(color: Color.fromRGBO(31, 31, 57, 0.7)),
      ),
    ),

    iconTheme: const IconThemeData(color: Color(0xFF1F1F39)),
  );
}
