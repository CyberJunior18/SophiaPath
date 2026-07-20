// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:sophia_path/screens/authentication/login.dart';
import 'package:sophia_path/widgets/profileImage.dart';
import 'package:sophia_path/widgets/tobeimplementedAlert.dart';
import 'package:provider/provider.dart';
import 'package:sophia_path/services/profile_state.dart';

import '../models/user/user.dart';
import '../screens/profile/achievements_screen.dart';
import '../screens/settings_screen.dart';
import '../services/user_preferences_services.dart';
import '../screens/authentication/authService.dart';

AppBar screenAppBar(
  BuildContext context,
  int index,
  VoidCallback onToggleTheme,
) {
  final profileState = Provider.of<ProfileState>(context);
  final user = profileState.currentUser ?? sampleUser;
  final theme = Theme.of(context);
  final colors = theme.colorScheme;

  final isGuest = profileState.currentUser == null;
  final profileIndex = isGuest ? 1 : 2;

  if (index == profileIndex) {
    return AppBar(
      backgroundColor: Colors.transparent,
      toolbarHeight: 60,
      title: Text(
        'Profile',
        style: theme.textTheme.titleLarge!.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (ctx) {
                  return SettingsScreen(onToggleTheme: onToggleTheme);
                },
              ),
            );
            profileState.refreshUser();
          },
        ),
      ],
    );
  }

  return AppBar(
    backgroundColor: theme.primaryColor,
    foregroundColor: Colors.white,
    toolbarHeight: 80,
    iconTheme: const IconThemeData(color: Colors.white),
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FittedBox(
          child: Text(
            (!isGuest && index == 0) ? 'Hi, ${user.fullName}' : 'Courses',
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontSize: 18,
            ),
          ),
        ),
        Text(
          (!isGuest && index == 0) ? "Let's start learning" : "Explore available courses",
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
      ],
    ),
    actions: [
      if (!isGuest)
      Padding(
        padding: const EdgeInsets.only(right: 16),
        child: PopupMenuButton<String>(
          offset: const Offset(0, 55),
          onSelected: (value) async {
            switch (value) {
              case 'achievements':
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (ctx) {
                      return AchievementsScreen();
                    },
                  ),
                );
                await profileState.refreshUser();
                break;
              case 'mode':
                onToggleTheme();
                break;
              case 'account':
                showDialog(
                  context: context,
                  builder: (ctx) {
                    return toBeImplemented(context);
                  },
                );
                break;
              case 'logout':
                try {
                  await UserPreferencesService.instance.clearAllData();
                  await AuthStorage.clearToken();
                  print('✅ Local data cleared');

                  if (context.mounted) {
                    Provider.of<ProfileState>(context, listen: false).refreshUser();
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) {
                          return LoginScreen(onToggleTheme: onToggleTheme);
                        },
                      ),
                      (route) => false,
                    );
                  }
                } catch (e) {
                  print('❌ Error during logout: $e');

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Logout failed: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'achievements',
              child: Row(
                children: [
                  Icon(Icons.emoji_events, color: colors.primary),
                  const SizedBox(width: 10),
                  const Text('Achievements'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'mode',
              child: Row(
                children: [
                  Icon(Icons.brightness_6, color: colors.primary),
                  const SizedBox(width: 10),
                  const Text('Change Mode'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'account',
              child: Row(
                children: [
                  Icon(Icons.person, color: colors.primary),
                  const SizedBox(width: 10),
                  const Text('Account'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'logout',
              child: Row(
                children: const [
                  Icon(Icons.logout, color: Colors.redAccent),
                  SizedBox(width: 10),
                  Text('Log out', style: TextStyle(color: Colors.redAccent)),
                ],
              ),
            ),
          ],
          child: ProfileImage(
            imageUrl: user.profileImage,
            radius: 25,
            name: user.fullName,
          ),
        ),
      ),
    ],
  );
}
