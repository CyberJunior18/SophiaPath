import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sophia_path/widgets/tobeimplementedAlert.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.onToggleTheme});
  final void Function() onToggleTheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Map<String, VoidCallback> settingsItems = {
      "Account": () {
        showDialog(
          context: context,
          builder: (ctx) {
            return toBeImplemented(context);
          },
        );
      },
      "Privacy": () {
        showDialog(
          context: context,
          builder: (ctx) {
            return toBeImplemented(context);
          },
        );
      },
      "Notifications": () {
        showDialog(
          context: context,
          builder: (ctx) {
            return toBeImplemented(context);
          },
        );
      },
      "Appearance": () {
        onToggleTheme();
      },
    };

    final itemIcon = [
      Icons.person,
      Icons.lock,
      Icons.notifications,
      Icons.dark_mode,
    ];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF3D5CFF),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Settings',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: ListView(
        children: [
          ...settingsItems.keys.map((item) {
            return ListTile(
              onTap: settingsItems[item],
              leading: Icon(
                itemIcon[settingsItems.keys.toList().indexOf(item)],
                color: theme.textTheme.bodyLarge!.color!,
              ),
              title: Text(
                item,
                style: GoogleFonts.poppins(
                  color: theme.textTheme.bodyLarge!.color!,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
