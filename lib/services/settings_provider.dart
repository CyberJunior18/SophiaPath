import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemePresetData {
  final int bg;
  final int card;
  final int text;
  final int primary;
  final bool isDark;
  const ThemePresetData({
    required this.bg,
    required this.card,
    required this.text,
    required this.primary,
    required this.isDark,
  });
}

class SettingsProvider extends ChangeNotifier {
  static const String _themePresetKey = 'settings_theme_preset';
  static const String _customColorsKey = 'settings_custom_colors';
  static const String _logoGradientKey = 'settings_logo_gradient';
  static const String _fontPreferenceKey = 'settings_font_preference';
  static const String _globalBgKey = 'settings_global_bg';
  static const String _bgStyleKey = 'settings_bg_style';
  static const String _notificationsKey = 'settings_notifications';
  static const String _emailUpdatesKey = 'settings_email_updates';

  static final Map<String, ThemePresetData> presets = {
    'light': const ThemePresetData(
      bg: 0xFFFCFDFF,
      card: 0xFFFFFFFF,
      text: 0xFF2D2D4D,
      primary: 0xFF3D5CFF,
      isDark: false,
    ),
    'dark': const ThemePresetData(
      bg: 0xFF161632,
      card: 0xFF1F1F39,
      text: 0xFFFFFFFF,
      primary: 0xFF3D5CFF,
      isDark: true,
    ),
    'sepia': const ThemePresetData(
      bg: 0xFFFDF6E3,
      card: 0xFFF5EEDC,
      text: 0xFF5C3E21,
      primary: 0xFF856404,
      isDark: false,
    ),
    'lava': const ThemePresetData(
      bg: 0xFF1C0A0A,
      card: 0xFF2C1414,
      text: 0xFFFFC83B,
      primary: 0xFFFF4500,
      isDark: true,
    ),
    'ocean': const ThemePresetData(
      bg: 0xFF0F3057,
      card: 0xFF143F6B,
      text: 0xFFE0F7FA,
      primary: 0xFF00BCD4,
      isDark: true,
    ),
    'forest': const ThemePresetData(
      bg: 0xFF0C2617,
      card: 0xFF133B24,
      text: 0xFFE2F3EB,
      primary: 0xFF10B981,
      isDark: true,
    ),
    'amber': const ThemePresetData(
      bg: 0xFF002B36,
      card: 0xFF073642,
      text: 0xFFFDF6E3,
      primary: 0xFFB58900,
      isDark: true,
    ),
    'dracula': const ThemePresetData(
      bg: 0xFF1E1F29,
      card: 0xFF282A36,
      text: 0xFFF8F8F2,
      primary: 0xFFFF79C6,
      isDark: true,
    ),
    'amethyst': const ThemePresetData(
      bg: 0xFF29153A,
      card: 0xFF3A1F52,
      text: 0xFFFAE8FF,
      primary: 0xFFD4AF37,
      isDark: true,
    ),
    'nordic': const ThemePresetData(
      bg: 0xFF3B4252,
      card: 0xFF434C5E,
      text: 0xFFECEFF4,
      primary: 0xFF88C0D0,
      isDark: true,
    ),
    'mint': const ThemePresetData(
      bg: 0xFFF4FEF9,
      card: 0xFFE6FAF0,
      text: 0xFF0F3D2A,
      primary: 0xFF00A86B,
      isDark: false,
    ),
    'lavender': const ThemePresetData(
      bg: 0xFFFDFAFF,
      card: 0xFFF5EEFF,
      text: 0xFF2E1065,
      primary: 0xFF7C3AED,
      isDark: false,
    ),
    'peach': const ThemePresetData(
      bg: 0xFFFFFEFC,
      card: 0xFFFFF6ED,
      text: 0xFF431407,
      primary: 0xFFEA580C,
      isDark: false,
    ),
    'rose': const ThemePresetData(
      bg: 0xFFFFFAFB,
      card: 0xFFFFF0F5,
      text: 0xFF500724,
      primary: 0xFFDB2777,
      isDark: false,
    ),
    'clay': const ThemePresetData(
      bg: 0xFFFAFAFA,
      card: 0xFFF3F4F6,
      text: 0xFF111827,
      primary: 0xFF4B5563,
      isDark: false,
    ),
    'kitty': const ThemePresetData(
      bg: 0xFFFFEBF0,
      card: 0xFFFFF2F5,
      text: 0xFF4A1525,
      primary: 0xFFFF6B8B,
      isDark: false,
    ),
    'midnight': const ThemePresetData(
      bg: 0xFF101726,
      card: 0xFF1E293B,
      text: 0xFFFFFFFF,
      primary: 0xFFFBC02D,
      isDark: true,
    ),
  };

  static final Map<String, String> defaultCustomColors = {
    'primaryMain': '#3D5CFF',
    'bgDefault': '#FFFFFF',
    'bgPaper': '#F7F9FC',
    'bgPaperAlt': '#E6F2FF',
    'textPrimary': '#1F1F39',
    'textSecondary': '#858597',
    'divider': '#E5E7EB',
    'codeBg': '#0F172A',
  };

  String _themePreset = 'light';
  final Map<String, String> _customColors = Map.from(defaultCustomColors);
  bool _logoGradient = false;
  String _fontPreference = 'default';
  bool _globalBg = false;
  String _bgStyle = 'constellation';
  bool _notifications = true;
  bool _emailUpdates = false;

  String get themePreset => _themePreset;
  Map<String, String> get customColors => _customColors;
  bool get logoGradient => _logoGradient;
  String get fontPreference => _fontPreference;
  bool get globalBg => _globalBg;
  String get bgStyle => _bgStyle;
  bool get notifications => _notifications;
  bool get emailUpdates => _emailUpdates;

  SettingsProvider() {
    loadSettings();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Check legacy theme preference first to preserve user preference
    if (prefs.containsKey('theme_preference') &&
        !prefs.containsKey(_themePresetKey)) {
      final isDark = prefs.getBool('theme_preference') ?? false;
      _themePreset = isDark ? 'dark' : 'light';
    } else {
      _themePreset = prefs.getString(_themePresetKey) ?? 'light';
    }

    final customColorsJson = prefs.getString(_customColorsKey);
    if (customColorsJson != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(customColorsJson);
        decoded.forEach((key, value) {
          _customColors[key] = value.toString();
        });
      } catch (_) {}
    }

    _logoGradient = prefs.getBool(_logoGradientKey) ?? false;
    _fontPreference = prefs.getString(_fontPreferenceKey) ?? 'default';
    _globalBg = prefs.getBool(_globalBgKey) ?? false;
    _bgStyle = prefs.getString(_bgStyleKey) ?? 'constellation';
    _notifications = prefs.getBool(_notificationsKey) ?? true;
    _emailUpdates = prefs.getBool(_emailUpdatesKey) ?? false;

    notifyListeners();
  }

  Future<void> setThemePreset(String preset) async {
    if (!presets.containsKey(preset) && preset != 'custom') return;
    _themePreset = preset;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themePresetKey, preset);
    // Keep legacy value synchronized so other screens query correctly if needed
    if (preset == 'dark' ||
        preset == 'lava' ||
        preset == 'ocean' ||
        preset == 'forest' ||
        preset == 'amber' ||
        preset == 'dracula' ||
        preset == 'amethyst' ||
        preset == 'nordic' ||
        preset == 'midnight') {
      await prefs.setBool('theme_preference', true);
    } else {
      await prefs.setBool('theme_preference', false);
    }
  }

  Future<void> updateCustomColor(String key, String hexValue) async {
    if (!_customColors.containsKey(key)) return;
    _customColors[key] = hexValue;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customColorsKey, jsonEncode(_customColors));
  }

  Future<void> setLogoGradient(bool enabled) async {
    _logoGradient = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_logoGradientKey, enabled);
  }

  Future<void> setFontPreference(String font) async {
    _fontPreference = font;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fontPreferenceKey, font);
  }

  Future<void> setGlobalBg(bool enabled) async {
    _globalBg = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_globalBgKey, enabled);
  }

  Future<void> setBgStyle(String style) async {
    _bgStyle = style;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bgStyleKey, style);
  }

  Future<void> setNotifications(bool enabled) async {
    _notifications = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsKey, enabled);
  }

  Future<void> setEmailUpdates(bool enabled) async {
    _emailUpdates = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_emailUpdatesKey, enabled);
  }

  Color parseColor(String hexStr, Color fallback) {
    try {
      var cleaned = hexStr.replaceAll('#', '').trim();
      if (cleaned.length == 6) {
        cleaned = 'FF$cleaned';
      }
      return Color(int.parse(cleaned, radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  ThemeData get themeData {
    final preset = presets[_themePreset];
    final bool isDark;
    final Color primaryColor;
    final Color scaffoldBgColor;
    final Color cardBgColor;
    final Color textColor;
    final Color secondaryColor;
    final Color dividerColor;

    if (_themePreset == 'custom') {
      isDark =
          ThemeData.estimateBrightnessForColor(
            parseColor(_customColors['bgDefault'] ?? '#FFFFFF', Colors.white),
          ) ==
          Brightness.dark;
      primaryColor = parseColor(
        _customColors['primaryMain'] ?? '#3D5CFF',
        const Color(0xFF3D5CFF),
      );
      scaffoldBgColor = parseColor(
        _customColors['bgDefault'] ?? '#FFFFFF',
        Colors.white,
      );
      cardBgColor = parseColor(
        _customColors['bgPaper'] ?? '#F7F9FC',
        const Color(0xFFF7F9FC),
      );
      textColor = parseColor(
        _customColors['textPrimary'] ?? '#1F1F39',
        const Color(0xFF1F1F39),
      );
      secondaryColor = parseColor(
        _customColors['bgPaperAlt'] ?? '#E6F2FF',
        const Color(0xFFE6F2FF),
      );
      dividerColor = parseColor(
        _customColors['divider'] ?? '#E5E7EB',
        const Color(0xFFE5E7EB),
      );
    } else if (preset != null) {
      isDark = preset.isDark;
      primaryColor = Color(preset.primary);
      scaffoldBgColor = Color(preset.bg);
      cardBgColor = Color(preset.card);
      textColor = Color(preset.text);
      secondaryColor = primaryColor.withValues(alpha: 0.12);
      dividerColor = isDark
          ? textColor.withValues(alpha: 0.12)
          : const Color(0xFFE5E7EB);
    } else {
      isDark = false;
      primaryColor = const Color(0xFF3D5CFF);
      scaffoldBgColor = const Color(0xFFF7F9FC);
      cardBgColor = Colors.white;
      textColor = const Color(0xFF1F1F39);
      secondaryColor = const Color(0xFFE6F2FF);
      dividerColor = const Color(0xFFE5E7EB);
    }

    final brightness = isDark ? Brightness.dark : Brightness.light;
    final colorScheme = isDark
        ? ColorScheme.dark(
            primary: primaryColor,
            secondary: secondaryColor,
            surface: cardBgColor,
            onSurface: textColor,
          )
        : ColorScheme.light(
            primary: primaryColor,
            secondary: secondaryColor,
            surface: cardBgColor,
            onSurface: textColor,
          );

    TextTheme baseTextTheme = isDark
        ? ThemeData.dark().textTheme
        : ThemeData.light().textTheme;
    TextTheme styledTextTheme;
    switch (_fontPreference) {
      case 'sans':
        styledTextTheme = GoogleFonts.interTextTheme(baseTextTheme);
        break;
      case 'serif':
        styledTextTheme = GoogleFonts.playfairDisplayTextTheme(baseTextTheme);
        break;
      case 'monospace':
        styledTextTheme = GoogleFonts.firaCodeTextTheme(baseTextTheme);
        break;
      case 'dyslexic':
        styledTextTheme = GoogleFonts.lexendDecaTextTheme(baseTextTheme);
        break;
      case 'default':
      default:
        styledTextTheme = GoogleFonts.poppinsTextTheme(baseTextTheme);
        break;
    }

    styledTextTheme = styledTextTheme.copyWith(
      bodyLarge: styledTextTheme.bodyLarge?.copyWith(color: textColor),
      bodyMedium: styledTextTheme.bodyMedium?.copyWith(
        color: textColor.withValues(alpha: 0.85),
      ),
      bodySmall: styledTextTheme.bodySmall?.copyWith(
        color: textColor.withValues(alpha: 0.65),
      ),
      titleLarge: styledTextTheme.titleLarge?.copyWith(
        color: textColor,
        fontWeight: FontWeight.bold,
      ),
      titleMedium: styledTextTheme.titleMedium?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: styledTextTheme.titleSmall?.copyWith(color: textColor),
    );

    return ThemeData(
      brightness: brightness,
      useMaterial3: true,
      scaffoldBackgroundColor: scaffoldBgColor,
      cardColor: cardBgColor,
      colorScheme: colorScheme,
      primaryColor: primaryColor,
      dividerColor: dividerColor,
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        elevation: 0,
        titleTextStyle: styledTextTheme.titleLarge?.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawerTheme: DrawerThemeData(backgroundColor: scaffoldBgColor),
      textTheme: styledTextTheme,
      iconTheme: IconThemeData(color: textColor),
      dialogTheme: DialogThemeData(backgroundColor: cardBgColor),
    );
  }
}
