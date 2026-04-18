// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:sophia_path/screens/authentication/login.dart';
import 'package:sophia_path/screens/authentication/edit_profile.dart';
import 'package:sophia_path/widgets/profileImage.dart';
import 'package:sophia_path/widgets/tobeimplementedAlert.dart';
import 'package:provider/provider.dart';
import 'package:sophia_path/services/profile_state.dart';

import '../models/user/user.dart';
import '../screens/profile/achievements_screen.dart';
import '../services/user_preferences_services.dart';

AppBar screenAppBar(
  BuildContext context,
  int index,
  VoidCallback onToggleTheme,
) {
  final profileState = Provider.of<ProfileState>(context);
  final user = profileState.currentUser ?? sampleUser;
  final theme = Theme.of(context);
  final colors = theme.colorScheme;

  if (index != 0) {
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
        TextButton(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (ctx) {
                  return EditProfile(onToggleTheme: onToggleTheme);
                },
              ),
            );
            profileState.refreshUser();
          },
          child: Text("Edit", style: theme.textTheme.titleMedium!),
        ),
      ],
    );
  }

  return AppBar(
    toolbarHeight: 80,
    iconTheme: const IconThemeData(color: Colors.white),
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FittedBox(
          child: Text(
            'Hi, ${user.fullName}',
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontSize: 18,
            ),
          ),
        ),
        Text(
          "Let's start learning",
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
      ],
    ),
    actions: [
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
                  print('✅ Local data cleared');

                  if (context.mounted) {
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
