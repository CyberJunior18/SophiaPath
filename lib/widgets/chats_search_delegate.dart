import 'package:flutter/material.dart';
import 'package:sophia_path/models/user/user.dart';

class ChatSearchDelegate extends SearchDelegate<String> {
  final List<User> users;

  ChatSearchDelegate({required this.users});

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final results = users
        .where(
          (user) =>
              user.fullName.toLowerCase().contains(query.toLowerCase()) ||
              user.tag.toLowerCase().contains(query.toLowerCase()) ||
              user.username.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();

    return _buildResultsList(results, context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final suggestions = users
        .where(
          (user) =>
              user.fullName.toLowerCase().contains(query.toLowerCase()) ||
              user.tag.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();

    return _buildResultsList(suggestions, context);
  }

  Widget _buildResultsList(List<User> results, BuildContext context) {
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final user = results[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: user.profileImage.isNotEmpty
                ? NetworkImage(user.profileImage)
                : const AssetImage('assets/default_avatar.png')
                      as ImageProvider,
          ),
          title: Text(user.fullName),
          subtitle: Text(user.tag),
          trailing: const Icon(Icons.message),
          onTap: () {
            close(context, user.username);
          },
        );
      },
    );
  }
}
