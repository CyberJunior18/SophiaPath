import 'package:flutter/material.dart';

class UserTile extends StatelessWidget {
  const UserTile({super.key, required this.text, this.onTap});
  final String text;
  final void Function()? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        // decoration: ,
        margin: EdgeInsets.all(20),
        child: Row(children: [Icon(Icons.person), Text(text)]),
      ),
    );
  }
}
