// import 'package:flutter/material.dart';
// import 'package:sophia_path/realauth/authService.dart';
// import 'package:sophia_path/realauth/login.dart';

// class HomePage extends StatefulWidget {
//   const HomePage({super.key});

//   @override
//   State<HomePage> createState() => _HomePageState();
// }

// class _HomePageState extends State<HomePage> {
//   final _authService = AuthService();

//   bool _isLoading = true;
//   String? _errorMessage;
//   Map<String, dynamic>? _profile;

//   // Map roleID to label and color
//   static const Map<int, Map<String, dynamic>> _roleInfo = {
//     0: {'label': 'Student', 'color': Color(0xFF4A90D9), 'icon': Icons.school},
//     1: {'label': 'Expert', 'color': Color(0xFF27AE60), 'icon': Icons.verified},
//     2: {'label': 'Admin', 'color': Color(0xFFE74C3C), 'icon': Icons.shield},
//   };

//   @override
//   void initState() {
//     super.initState();
//     _loadProfile();
//   }

//   Future<void> _loadProfile() async {
//     setState(() {
//       _isLoading = true;
//       _errorMessage = null;
//     });

//     final result = await _authService.getProfile();

//     setState(() => _isLoading = false);

//     if (result['success'] == true) {
//       setState(() => _profile = result['data']);
//     } else {
//       setState(() => _errorMessage = result['message']);
//     }
//   }

//   void _handleLogout() {
//     _authService.logout();
//     Navigator.pushAndRemoveUntil(
//       context,
//       MaterialPageRoute(builder: (_) => const LoginScreen()),
//       (route) => false,
//     );
//   }

//   String _formatDateTime(String? raw) {
//     if (raw == null) return 'N/A';
//     try {
//       final dt = DateTime.parse(raw).toLocal();
//       return '${dt.year}-${_pad(dt.month)}-${_pad(dt.day)}  '
//           '${_pad(dt.hour)}:${_pad(dt.minute)}';
//     } catch (_) {
//       return raw;
//     }
//   }

//   String _pad(int n) => n.toString().padLeft(2, '0');

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFF4F6FB),
//       appBar: AppBar(
//         title: const Text(
//           'Profile',
//           style: TextStyle(fontWeight: FontWeight.bold),
//         ),
//         backgroundColor: Colors.white,
//         foregroundColor: Colors.black,
//         elevation: 0.5,
//         actions: [
//           IconButton(
//             tooltip: 'Logout',
//             icon: const Icon(Icons.logout),
//             onPressed: _handleLogout,
//           ),
//         ],
//       ),
//       body: _buildBody(),
//     );
//   }

//   Widget _buildBody() {
//     if (_isLoading) {
//       return const Center(child: CircularProgressIndicator());
//     }

//     if (_errorMessage != null) {
//       return Center(
//         child: Padding(
//           padding: const EdgeInsets.all(24),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               const Icon(Icons.error_outline, color: Colors.red, size: 48),
//               const SizedBox(height: 12),
//               Text(
//                 _errorMessage!,
//                 textAlign: TextAlign.center,
//                 style: const TextStyle(color: Colors.red),
//               ),
//               const SizedBox(height: 20),
//               ElevatedButton.icon(
//                 onPressed: _loadProfile,
//                 icon: const Icon(Icons.refresh),
//                 label: const Text('Retry'),
//               ),
//             ],
//           ),
//         ),
//       );
//     }

//     if (_profile == null) return const SizedBox();

//     final username = _profile!['username'] ?? 'Unknown';
//     final email = _profile!['email'] ?? 'Unknown';
//     final roleID = (_profile!['roleID'] as num?)?.toInt() ?? 0;
//     final dateTime = _profile!['dateTime']?.toString();

//     final role = _roleInfo[roleID] ?? _roleInfo[0]!;
//     final roleLabel = role['label'] as String;
//     final roleColor = role['color'] as Color;
//     final roleIcon = role['icon'] as IconData;

//     // Avatar initials
//     final initials = username.isNotEmpty ? username[0].toUpperCase() : '?';

//     return RefreshIndicator(
//       onRefresh: _loadProfile,
//       child: ListView(
//         padding: const EdgeInsets.all(20),
//         children: [
//           const SizedBox(height: 12),

//           // ── Avatar & Name ──────────────────────────────────────────
//           Center(
//             child: Column(
//               children: [
//                 CircleAvatar(
//                   radius: 48,
//                   backgroundColor: roleColor,
//                   child: Text(
//                     initials,
//                     style: const TextStyle(
//                       fontSize: 36,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.white,
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 14),
//                 Text(
//                   username,
//                   style: const TextStyle(
//                     fontSize: 22,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 const SizedBox(height: 6),
//                 // Role Badge
//                 Container(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 14,
//                     vertical: 5,
//                   ),
//                   decoration: BoxDecoration(
//                     color: roleColor.withOpacity(0.12),
//                     borderRadius: BorderRadius.circular(20),
//                     border: Border.all(color: roleColor.withOpacity(0.4)),
//                   ),
//                   child: Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Icon(roleIcon, size: 15, color: roleColor),
//                       const SizedBox(width: 5),
//                       Text(
//                         roleLabel,
//                         style: TextStyle(
//                           color: roleColor,
//                           fontWeight: FontWeight.w600,
//                           fontSize: 13,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),

//           const SizedBox(height: 28),

//           // ── Info Card ──────────────────────────────────────────────
//           Container(
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(16),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(0.06),
//                   blurRadius: 12,
//                   offset: const Offset(0, 4),
//                 ),
//               ],
//             ),
//             child: Column(
//               children: [
//                 _infoTile(
//                   icon: Icons.person_outline,
//                   label: 'Username',
//                   value: username,
//                   iconColor: Colors.indigo,
//                 ),
//                 _divider(),
//                 _infoTile(
//                   icon: Icons.email_outlined,
//                   label: 'Email',
//                   value: email,
//                   iconColor: Colors.teal,
//                 ),
//                 _divider(),
//                 _infoTile(
//                   icon: roleIcon,
//                   label: 'Role',
//                   value: roleLabel,
//                   iconColor: roleColor,
//                   valueColor: roleColor,
//                 ),
//                 _divider(),
//                 _infoTile(
//                   icon: Icons.calendar_today_outlined,
//                   label: 'Member Since',
//                   value: _formatDateTime(dateTime),
//                   iconColor: Colors.orange,
//                 ),
//               ],
//             ),
//           ),

//           const SizedBox(height: 32),

//           // ── Logout Button ──────────────────────────────────────────
//           SizedBox(
//             height: 50,
//             child: OutlinedButton.icon(
//               onPressed: _handleLogout,
//               icon: const Icon(Icons.logout, color: Colors.red),
//               label: const Text(
//                 'Logout',
//                 style: TextStyle(color: Colors.red, fontSize: 16),
//               ),
//               style: OutlinedButton.styleFrom(
//                 side: const BorderSide(color: Colors.red),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _infoTile({
//     required IconData icon,
//     required String label,
//     required String value,
//     required Color iconColor,
//     Color? valueColor,
//     bool isLast = false,
//   }) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
//       child: Row(
//         children: [
//           Container(
//             padding: const EdgeInsets.all(8),
//             decoration: BoxDecoration(
//               color: iconColor.withOpacity(0.1),
//               borderRadius: BorderRadius.circular(10),
//             ),
//             child: Icon(icon, color: iconColor, size: 20),
//           ),
//           const SizedBox(width: 16),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   label,
//                   style: const TextStyle(
//                     fontSize: 12,
//                     color: Colors.grey,
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//                 const SizedBox(height: 2),
//                 Text(
//                   value,
//                   style: TextStyle(
//                     fontSize: 15,
//                     fontWeight: FontWeight.w600,
//                     color: valueColor ?? Colors.black87,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _divider() => const Divider(height: 1, indent: 20, endIndent: 20);
// }
