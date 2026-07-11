import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:sophia_path/screens/authentication/login.dart';
import 'package:sophia_path/services/profile_state.dart';
import 'package:sophia_path/services/settings_provider.dart';
import 'package:sophia_path/services/user_preferences_services.dart';
import 'package:sophia_path/screens/authentication/authService.dart';
import 'package:sophia_path/widgets/background_animation_widget.dart';

class SettingsScreen extends StatefulWidget {
  final void Function() onToggleTheme;
  const SettingsScreen({super.key, required this.onToggleTheme});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final List<String> _fontOptions = ['default', 'sans', 'serif', 'monospace', 'dyslexic'];
  final List<String> _bgStyles = ['constellation', 'circuit', 'aurora', 'grid', 'matrix', 'vortex', 'warp'];

  String _getFontLabel(String key) {
    switch (key) {
      case 'sans':
        return 'Inter (Sans-Serif)';
      case 'serif':
        return 'Playfair Display (Serif)';
      case 'monospace':
        return 'Fira Code (Monospace)';
      case 'dyslexic':
        return 'Lexend Deca (Dyslexic-Friendly)';
      case 'default':
      default:
        return 'Poppins (Default)';
    }
  }

  String _getBgStyleLabel(String key) {
    switch (key) {
      case 'circuit':
        return 'Circuit Board';
      case 'aurora':
        return 'Aurora Waves';
      case 'grid':
        return 'Perspective Grid';
      case 'matrix':
        return 'Matrix Rain';
      case 'vortex':
        return 'Cosmic Vortex';
      case 'warp':
        return 'Starfield Warp';
      case 'constellation':
      default:
        return 'Constellation';
    }
  }

  void _showColorPickerDialog(
    BuildContext context,
    SettingsProvider settings,
    String key,
    String currentColor,
  ) {
    final textController = TextEditingController(text: currentColor);
    final List<String> pickerColors = [
      '#3D5CFF', '#FF3D57', '#3DFF57', '#FF9F3D', '#9F3DFF', '#3DFFE3',
      '#1F1F39', '#858597', '#E6F2FF', '#FFFFFF', '#0F172A', '#F7F9FC',
      '#1E1F29', '#0C2617', '#0F3057', '#29153A', '#3B4252', '#FDF6E3',
      '#E5E7EB', '#00A86B'
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: Text(
            'Pick a color for $key',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Grid of quick colors
                SizedBox(
                  width: 280,
                  height: 180,
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: pickerColors.length,
                    itemBuilder: (context, index) {
                      final c = pickerColors[index];
                      final isSelected = c.toLowerCase() == textController.text.toLowerCase();
                      return GestureDetector(
                        onTap: () {
                          textController.text = c;
                          (ctx as Element).markNeedsBuild();
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: settings.parseColor(c, Colors.grey),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? theme.primaryColor : Colors.grey.shade400,
                              width: isSelected ? 3.0 : 1.0,
                            ),
                          ),
                          child: isSelected
                              ? Icon(
                                  Icons.check,
                                  color: ThemeData.estimateBrightnessForColor(
                                              settings.parseColor(c, Colors.grey)) ==
                                          Brightness.dark
                                      ? Colors.white
                                      : Colors.black,
                                  size: 16,
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                // Text input
                TextField(
                  controller: textController,
                  decoration: InputDecoration(
                    labelText: 'Hex Color Code',
                    hintText: '#FFFFFF',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.color_lens_outlined),
                  ),
                  maxLength: 7,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final text = textController.text.trim();
                if (RegExp(r'^#?[0-9a-fA-F]{6}$').hasMatch(text)) {
                  var formatted = text;
                  if (!formatted.startsWith('#')) {
                    formatted = '#$formatted';
                  }
                  settings.updateCustomColor(key, formatted);
                  Navigator.pop(ctx);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Invalid Hex Color format (e.g. #3D5CFF)'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _exportData() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.download_done, color: Colors.green),
            SizedBox(width: 8),
            Text('Export Successful'),
          ],
        ),
        content: const Text(
          'Your personal learning achievements, courses enrolled, and profiles preferences have been compiled into a JSON backup file and saved to your device downloads folder.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text('Delete Account?'),
            ],
          ),
          content: const Text(
            'Are you sure you want to permanently delete your account? This action will remove all local data, credentials, and achievements. This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(ctx); // Close dialog
                try {
                  // Clear SharedPreferences
                  await UserPreferencesService.instance.clearAllData();
                  // Remove token
                  await AuthStorage.clearToken();
                  
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LoginScreen(onToggleTheme: widget.onToggleTheme),
                      ),
                      (route) => false,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Account data cleared successfully.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to delete account data: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Delete Permanently'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final profileState = Provider.of<ProfileState>(context);
    final user = profileState.currentUser;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
      ),
      body: BackgroundAnimationWidget(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20),
          children: [
            // Subtitle header
            Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SophiaPath Preferences',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage your account configurations and style preferences.',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),

            // SECTION 1: Account info
            _buildSectionHeader('Account Details'),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: theme.dividerColor, width: 1),
              ),
              color: theme.cardColor,
              margin: const EdgeInsets.only(bottom: 24),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildRowItem(
                      icon: Icons.alternate_email,
                      title: 'Email Address',
                      value: user?.email.isNotEmpty == true ? user!.email : 'test@example.com',
                      isTransparent: true,
                    ),
                    const Divider(height: 24),
                    _buildRowItem(
                      icon: Icons.lock_outline,
                      title: 'Password Status',
                      value: 'Last changed 3 months ago',
                      isTransparent: true,
                    ),
                  ],
                ),
              ),
            ),

            // SECTION 2: Style preferences
            _buildSectionHeader('Theme & Visual Styling'),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: theme.dividerColor, width: 1),
              ),
              color: theme.cardColor,
              margin: const EdgeInsets.only(bottom: 24),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'App Theme Presets',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Theme presets Grid
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 2.2,
                      ),
                      itemCount: SettingsProvider.presets.length + 1,
                      itemBuilder: (context, index) {
                        final String id;
                        final String name;
                        final Color bg;
                        final Color primary;
                        final bool isCustom = index == SettingsProvider.presets.length;

                        if (isCustom) {
                          id = 'custom';
                          name = 'Custom';
                          bg = settings.parseColor(
                              settings.customColors['bgDefault'] ?? '#FFFFFF', Colors.white);
                          primary = settings.parseColor(
                              settings.customColors['primaryMain'] ?? '#3D5CFF', const Color(0xFF3D5CFF));
                        } else {
                          final keys = SettingsProvider.presets.keys.toList();
                          id = keys[index];
                          final data = SettingsProvider.presets[id]!;
                          name = id[0].toUpperCase() + id.substring(1);
                          bg = Color(data.bg);
                          primary = Color(data.primary);
                        }

                        final isSelected = settings.themePreset == id;

                        return GestureDetector(
                          onTap: () => settings.setThemePreset(id),
                          child: Container(
                            decoration: BoxDecoration(
                              color: bg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected ? theme.primaryColor : theme.dividerColor,
                                width: isSelected ? 2.5 : 1.0,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: theme.primaryColor.withValues(alpha: 0.15),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      )
                                    ]
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: ThemeData.estimateBrightnessForColor(bg) == Brightness.dark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    if (settings.themePreset == 'custom') ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Divider(),
                      ),
                      Text(
                        'Custom Color Palette',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Custom colors editor
                      ...settings.customColors.keys.map((colorKey) {
                        final hex = settings.customColors[colorKey] ?? '#FFFFFF';
                        final color = settings.parseColor(hex, Colors.grey);
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.grey.shade400, width: 1),
                            ),
                          ),
                          title: Text(
                            colorKey,
                            style: GoogleFonts.poppins(fontSize: 13),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              border: Border.all(color: theme.dividerColor),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              hex.toUpperCase(),
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          onTap: () => _showColorPickerDialog(context, settings, colorKey, hex),
                        );
                      }),
                    ],

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(),
                    ),

                    // Typography selection
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Font Family',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: theme.textTheme.bodyLarge?.color,
                              ),
                            ),
                            Text(
                              'Select default text typeface',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                        DropdownButton<String>(
                          value: settings.fontPreference,
                          underline: Container(),
                          style: GoogleFonts.poppins(
                            color: theme.textTheme.bodyLarge?.color,
                            fontWeight: FontWeight.w600,
                          ),
                          onChanged: (val) {
                            if (val != null) settings.setFontPreference(val);
                          },
                          items: _fontOptions.map((opt) {
                            return DropdownMenuItem<String>(
                              value: opt,
                              child: Text(_getFontLabel(opt)),
                            );
                          }).toList(),
                        )
                      ],
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(),
                    ),

                    // Background animation toggle
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Global Background Animation',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                      subtitle: Text(
                        'Renders abstract movement behind pages',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                        ),
                      ),
                      value: settings.globalBg,
                      onChanged: (val) => settings.setGlobalBg(val),
                    ),

                    if (settings.globalBg) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Animation Style',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: theme.textTheme.bodyLarge?.color,
                            ),
                          ),
                          DropdownButton<String>(
                            value: settings.bgStyle,
                            underline: Container(),
                            style: GoogleFonts.poppins(
                              color: theme.textTheme.bodyLarge?.color,
                              fontWeight: FontWeight.w600,
                            ),
                            onChanged: (val) {
                              if (val != null) settings.setBgStyle(val);
                            },
                            items: _bgStyles.map((opt) {
                              return DropdownMenuItem<String>(
                                value: opt,
                                child: Text(_getBgStyleLabel(opt)),
                              );
                            }).toList(),
                          )
                        ],
                      ),
                    ],

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(),
                    ),

                    // Logo style toggle
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Logo Smooth Gradient',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                      subtitle: Text(
                        'Apply colorful gradient to brand icons',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                        ),
                      ),
                      value: settings.logoGradient,
                      onChanged: (val) => settings.setLogoGradient(val),
                    ),
                  ],
                ),
              ),
            ),

            // SECTION 3: Communication preferences
            _buildSectionHeader('Communications'),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: theme.dividerColor, width: 1),
              ),
              color: theme.cardColor,
              margin: const EdgeInsets.only(bottom: 24),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Push Notifications',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                      value: settings.notifications,
                      onChanged: (val) => settings.setNotifications(val),
                    ),
                    const Divider(height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Email Marketing Updates',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                      value: settings.emailUpdates,
                      onChanged: (val) => settings.setEmailUpdates(val),
                    ),
                  ],
                ),
              ),
            ),

            // SECTION 4: Data and privacy
            _buildSectionHeader('Data & Privacy'),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: theme.dividerColor, width: 1),
              ),
              color: theme.cardColor,
              margin: const EdgeInsets.only(bottom: 24),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.download, color: theme.primaryColor),
                      title: Text(
                        'Export Learning Data',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _exportData,
                    ),
                    const Divider(height: 8),
                    ListTile(
                      leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
                      title: Text(
                        'Delete Account',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.redAccent,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right, color: Colors.redAccent),
                      onTap: _confirmDeleteAccount,
                    ),
                  ],
                ),
              ),
            ),

            // Footer brand signature
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 20),
              child: Center(
                child: Column(
                  children: [
                    Text(
                      'SophiaPath Mobile • Version 1.0.0',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Built with ❤️ for Learners',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 10),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: theme.primaryColor,
        ),
      ),
    );
  }

  Widget _buildRowItem({
    required IconData icon,
    required String title,
    required String value,
    bool isTransparent = false,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: theme.primaryColor.withValues(alpha: 0.8), size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
