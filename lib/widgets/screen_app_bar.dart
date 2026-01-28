// ignore_for_file: file_names

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sophia_path/screens/register_screen.dart';
import 'package:sophia_path/widgets/tobeimplementedAlert.dart';
import 'package:provider/provider.dart';
import 'package:sophia_path/services/profile_state.dart';

import '../models/user/user.dart';
import '../screens/profile/achievements_screen.dart';

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
            await Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (ctx) {
                  return MyAuthScreen(
                    isEditing: true,
                    onToggleTheme: onToggleTheme,
                  );
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
          itemBuilder: (context) => [
            PopupMenuItem(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (ctx) {
                      return AchievementsScreen();
                    },
                  ),
                );
              },
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
              onTap: onToggleTheme,
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
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) {
                    return toBeImplemented(context);
                  },
                );
              },
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
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) {
                    return toBeImplemented(context);
                  },
                );
              },
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
          child: CircleAvatar(
            radius: 25,
            backgroundImage: _getProfileImage(user.profileImage),
          ),
        ),
      ),
    ],
  );
}

ImageProvider _getProfileImage(String imagePath) {
  if (imagePath.startsWith('http')) {
    return NetworkImage(imagePath);
  } else if (imagePath.isNotEmpty) {
    return FileImage(File(imagePath));
  } else {
    return const NetworkImage(
      'https://cdn.wallpapersafari.com/95/19/uFaSYI.jpg',
    );
  }
}
