import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/course/lessonContent.dart' as lesson_content_model;

class CyberLabWidget extends StatelessWidget {
  final lesson_content_model.LessonBlock block;

  const CyberLabWidget({super.key, required this.block});

  @override
  Widget build(BuildContext context) {
    final value = block.raw['value'] ?? '';
    final isMitigated = value.endsWith('-patch');
    final labType = isMitigated ? value.substring(0, value.length - 6) : value;

    Widget labComponent;
    String labTitle;

    switch (labType) {
      case 'DOS':
        labComponent = DenialOfServiceLabWidget(startMitigated: isMitigated);
        labTitle = isMitigated
            ? 'Denial of Service (DoS) Mitigation Lab'
            : 'Denial of Service (DoS) Attack Lab';
        break;
      case 'DDOS':
        labComponent = DistributedDenialOfServiceLabWidget(
          startMitigated: isMitigated,
        );
        labTitle = isMitigated
            ? 'Distributed Denial of Service (DDoS) Mitigation Lab'
            : 'Distributed Denial of Service (DDoS) Attack Lab';
        break;
      case 'RANSOMWARE':
        labComponent = RansomwareLabWidget(startMitigated: isMitigated);
        labTitle = isMitigated
            ? 'Ransomware Protection (EDR) Lab'
            : 'Ransomware Infiltration Lab';
        break;
      case 'SOCIAL':
        labComponent = SocialEngineeringLabWidget(startMitigated: isMitigated);
        labTitle = isMitigated
            ? 'Social Engineering Defense Lab'
            : 'Social Engineering Attack Simulator';
        break;
      case 'INSIDER':
        labComponent = InsiderThreatLabWidget(startMitigated: isMitigated);
        labTitle = isMitigated
            ? 'Insider Threat Detection (UEBA/DLP) Lab'
            : 'Insider Threat Exfiltration Simulator';
        break;
      default:
        return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E38).withOpacity(0.4) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.08),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: 10,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  labTitle,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Interactive Simulation & Mitigation',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),
          // Lab Component
          labComponent,
        ],
      ),
    );
  }
}

// ==========================================
// 1. Denial of Service (DoS) Lab
// ==========================================

class _DosRequestParticle {
  final double startX;
  final double startY;
  final double targetX;
  final double targetY;
  final String type;
  double progress = 0.0;
  final int id;

  _DosRequestParticle({
    required this.id,
    required this.startX,
    required this.startY,
    required this.targetX,
    required this.targetY,
    required this.type,
  });
}

class DenialOfServiceLabWidget extends StatefulWidget {
  final bool startMitigated;

  const DenialOfServiceLabWidget({super.key, required this.startMitigated});

  @override
  State<DenialOfServiceLabWidget> createState() =>
      _DenialOfServiceLabWidgetState();
}

class _DenialOfServiceLabWidgetState extends State<DenialOfServiceLabWidget>
    with SingleTickerProviderStateMixin {
  double requestLevel = 20.0;
  late bool firewallEnabled;
  final List<_DosRequestParticle> requests = [];

  Ticker? _ticker;
  Duration _lastElapsed = Duration.zero;
  Duration _lastNormalSpawn = Duration.zero;
  Duration _lastAttackerSpawn = Duration.zero;

  @override
  void initState() {
    super.initState();
    firewallEnabled = widget.startMitigated;
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  Offset getTarget(double cx, double cy, double targetRadius) {
    const serverX = 380.0;
    const serverY = 250.0;
    final angle = atan2(serverY - cy, serverX - cx);
    return Offset(
      serverX - targetRadius * cos(angle),
      serverY - targetRadius * sin(angle),
    );
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    final dt = (elapsed - _lastElapsed).inMilliseconds;
    _lastElapsed = elapsed;

    final isOverloaded = requestLevel > 70;
    final status = isOverloaded
        ? (firewallEnabled ? 'protected' : 'crashing')
        : 'normal';

    // Update particle positions
    setState(() {
      for (var i = requests.length - 1; i >= 0; i--) {
        final req = requests[i];
        req.progress += dt / 800.0;
        if (req.progress >= 1.0) {
          requests.removeAt(i);
        }
      }
    });

    // Attacker spawn logic
    final spawnSpeed = (600.0 - (requestLevel * 5.85))
        .clamp(15.0, 600.0)
        .toInt();
    if (elapsed - _lastAttackerSpawn > Duration(milliseconds: spawnSpeed)) {
      _lastAttackerSpawn = elapsed;
      final targetR = status == 'protected' ? 80.0 + 25.0 : 45.0 + 4.0;
      final target = getTarget(80.0, 250.0, targetR);
      setState(() {
        requests.add(
          _DosRequestParticle(
            id: DateTime.now().microsecondsSinceEpoch,
            startX: 80.0,
            startY: 250.0,
            targetX: target.dx,
            targetY: target.dy,
            type: 'attacker',
          ),
        );
      });
    }

    // Normal spawn logic
    if (elapsed - _lastNormalSpawn > const Duration(milliseconds: 800)) {
      _lastNormalSpawn = elapsed;
      final userY = Random().nextBool() ? 100.0 : 400.0;
      final target = getTarget(80.0, userY, 45.0 + 4.0);
      setState(() {
        requests.add(
          _DosRequestParticle(
            id: DateTime.now().microsecondsSinceEpoch,
            startX: 80.0,
            startY: userY,
            targetX: target.dx,
            targetY: target.dy,
            type: 'normal',
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOverloaded = requestLevel > 70;
    final status = isOverloaded
        ? (firewallEnabled ? 'protected' : 'crashing')
        : 'normal';

    return Column(
      children: [
        // SVG Visualizer Canvas
        AspectRatio(
          aspectRatio: 550 / 440,
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: CustomPaint(
              painter: _DosPainter(
                requestLevel: requestLevel,
                firewallEnabled: firewallEnabled,
                requests: requests,
                status: status,
              ),
            ),
          ),
        ),
        // Controls
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Attacker Request Volume',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Slider(
                          min: 0,
                          max: 100,
                          value: requestLevel,
                          activeColor: isOverloaded
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF3D5CFF),
                          onChanged: (val) {
                            setState(() {
                              requestLevel = val;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    children: [
                      Text(
                        'IP Block',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Switch(
                        value: firewallEnabled,
                        activeThumbColor: const Color(0xFF10B981),
                        onChanged: (val) {
                          setState(() {
                            firewallEnabled = val;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        // Status banner
        _buildStatusBanner(status),
      ],
    );
  }

  Widget _buildStatusBanner(String status) {
    Color color;
    String title;
    String desc;

    if (status == 'normal') {
      color = const Color(0xFF10B981);
      title = 'Server handling traffic';
      desc = 'Attacker volume is low, all requests processed successfully.';
    } else if (status == 'crashing') {
      color = const Color(0xFFEF4444);
      title = 'Server Crashing!';
      desc =
          'Single source flooding resources. Legitimate users are locked out.';
    } else {
      color = const Color(0xFF10B981);
      title = 'IP Block Active';
      desc =
          'Firewall is dropping traffic from the attacker\'s IP. Normal users unaffected.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 2. Distributed Denial of Service (DDoS) Lab
// ==========================================

class _DdosRequestParticle {
  final double startX;
  final double startY;
  final double targetX;
  final double targetY;
  final bool isRed;
  double progress = 0.0;
  final int id;

  _DdosRequestParticle({
    required this.id,
    required this.startX,
    required this.startY,
    required this.targetX,
    required this.targetY,
    required this.isRed,
  });
}

class _DdosClient {
  final int id;
  final double cx;
  final double cy;
  final double angle;
  final bool isRedBase;

  _DdosClient({
    required this.id,
    required this.cx,
    required this.cy,
    required this.angle,
    required this.isRedBase,
  });
}

List<_DdosClient> getClients(int numClients, double requestLevel) {
  const center = 250.0;
  const orbitRadius = 190.0;
  final List<_DdosClient> list = [];
  for (int i = 0; i < numClients; i++) {
    final angle = (i / numClients) * 2 * pi - pi / 2;
    final cx = center + orbitRadius * cos(angle);
    final cy = center + orbitRadius * sin(angle);
    final isRedBase = (i % 2 != 0 || i % 3 == 0) && requestLevel > 40;
    list.add(
      _DdosClient(id: i, cx: cx, cy: cy, angle: angle, isRedBase: isRedBase),
    );
  }
  return list;
}

class DistributedDenialOfServiceLabWidget extends StatefulWidget {
  final bool startMitigated;

  const DistributedDenialOfServiceLabWidget({
    super.key,
    required this.startMitigated,
  });

  @override
  State<DistributedDenialOfServiceLabWidget> createState() =>
      _DistributedDenialOfServiceLabWidgetState();
}

class _DistributedDenialOfServiceLabWidgetState
    extends State<DistributedDenialOfServiceLabWidget>
    with SingleTickerProviderStateMixin {
  double requestLevel = 20.0;
  late bool firewallEnabled;
  final List<_DdosRequestParticle> externalRequests = [];
  final List<_DdosRequestParticle> internalRequests = [];

  Ticker? _ticker;
  Duration _lastElapsed = Duration.zero;
  Duration _lastExtSpawn = Duration.zero;
  Duration _lastIntSpawn = Duration.zero;

  @override
  void initState() {
    super.initState();
    firewallEnabled = widget.startMitigated;
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    final dt = (elapsed - _lastElapsed).inMilliseconds;
    _lastElapsed = elapsed;

    final isOverloaded = requestLevel > 70;
    final status = isOverloaded
        ? (firewallEnabled ? 'protected' : 'crashing')
        : 'normal';

    final numClients = (4 + (requestLevel / 100.0) * 28).floor();
    final clients = getClients(numClients, requestLevel);

    setState(() {
      // Update external
      for (var i = externalRequests.length - 1; i >= 0; i--) {
        final req = externalRequests[i];
        req.progress += dt / 800.0;
        if (req.progress >= 1.0) {
          externalRequests.removeAt(i);
        }
      }
      // Update internal
      for (var i = internalRequests.length - 1; i >= 0; i--) {
        final req = internalRequests[i];
        req.progress += dt / 400.0;
        if (req.progress >= 1.0) {
          internalRequests.removeAt(i);
        }
      }
    });

    // Spawn external
    final extSpawnSpeed = (800.0 - (requestLevel * 7.8))
        .clamp(20.0, 800.0)
        .toInt();
    if (elapsed - _lastExtSpawn > Duration(milliseconds: extSpawnSpeed)) {
      _lastExtSpawn = elapsed;
      if (clients.isNotEmpty) {
        final client = clients[Random().nextInt(clients.length)];
        final isRed = status == 'crashing' ? true : client.isRedBase;
        final targetR = status == 'protected' ? 75.0 : 45.0 + 4.0;
        final tx = 250.0 + targetR * cos(client.angle);
        final ty = 250.0 + targetR * sin(client.angle);

        setState(() {
          externalRequests.add(
            _DdosRequestParticle(
              id: DateTime.now().microsecondsSinceEpoch,
              startX: client.cx,
              startY: client.cy,
              targetX: tx,
              targetY: ty,
              isRed: isRed,
            ),
          );
        });
      }
    }

    // Spawn internal
    if (status == 'protected') {
      if (elapsed - _lastIntSpawn > const Duration(milliseconds: 250)) {
        _lastIntSpawn = elapsed;
        final index = Random().nextInt(8);
        final angle = (index / 8.0) * 2 * pi;
        final cx = 250.0 + 55.0 * cos(angle);
        final cy = 250.0 + 55.0 * sin(angle);
        final tx = 250.0 + (45.0 + 4.0) * cos(angle);
        final ty = 250.0 + (45.0 + 4.0) * sin(angle);

        setState(() {
          internalRequests.add(
            _DdosRequestParticle(
              id: DateTime.now().microsecondsSinceEpoch + 1,
              startX: cx,
              startY: cy,
              targetX: tx,
              targetY: ty,
              isRed: false,
            ),
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOverloaded = requestLevel > 70;
    final status = isOverloaded
        ? (firewallEnabled ? 'protected' : 'crashing')
        : 'normal';

    return Column(
      children: [
        // Canvas aspect ratio 1:1
        AspectRatio(
          aspectRatio: 1.0,
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: CustomPaint(
              painter: _DdosPainter(
                requestLevel: requestLevel,
                firewallEnabled: firewallEnabled,
                externalRequests: externalRequests,
                internalRequests: internalRequests,
                status: status,
              ),
            ),
          ),
        ),
        // Controls
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Request Volume',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Slider(
                      min: 1,
                      max: 100,
                      value: requestLevel,
                      activeColor: isOverloaded
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF3D5CFF),
                      onChanged: (val) {
                        setState(() {
                          requestLevel = val;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                children: [
                  Text(
                    'Firewall',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Switch(
                    value: firewallEnabled,
                    activeThumbColor: const Color(0xFF10B981),
                    onChanged: (val) {
                      setState(() {
                        firewallEnabled = val;
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        _buildStatusBanner(status),
      ],
    );
  }

  Widget _buildStatusBanner(String status) {
    Color color;
    String title;
    String desc;

    if (status == 'normal') {
      color = const Color(0xFF10B981);
      title = 'Server works normally';
      desc = 'Number of requests is within safe operational capacity limits.';
    } else if (status == 'crashing') {
      color = const Color(0xFFEF4444);
      title = 'Server Crashing!';
      desc =
          'Traffic is exceeding maximum throughput capacity. System offline.';
    } else {
      color = const Color(0xFF10B981);
      title = 'Firewall Organizing Traffic';
      desc =
          'Filtering out automated packet floods and routing verified client queues.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 3. Ransomware Lab
// ==========================================

class _RansomwareFile {
  final int id;
  String status = 'normal';

  _RansomwareFile({required this.id});
}

class RansomwareLabWidget extends StatefulWidget {
  final bool startMitigated;

  const RansomwareLabWidget({super.key, required this.startMitigated});

  @override
  State<RansomwareLabWidget> createState() => _RansomwareLabWidgetState();
}

class _RansomwareLabWidgetState extends State<RansomwareLabWidget>
    with SingleTickerProviderStateMixin {
  String attackPhase =
      'idle'; // idle, sending, encrypting, ransomed, blocked, restoring
  late bool edrEnabled;
  double payloadPos = 0.0;
  final List<_RansomwareFile> files = List.generate(
    12,
    (i) => _RansomwareFile(id: i),
  );

  Ticker? _ticker;
  Duration _lastElapsed = Duration.zero;
  Duration _lastEncryptionStep = Duration.zero;
  Duration _lastRestoreStep = Duration.zero;

  @override
  void initState() {
    super.initState();
    edrEnabled = widget.startMitigated;
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    final dt = (elapsed - _lastElapsed).inMilliseconds;
    _lastElapsed = elapsed;

    if (attackPhase == 'sending') {
      setState(() {
        payloadPos += dt * (100.0 / 1000.0); // 1 second flight time
        if (edrEnabled && payloadPos >= 73) {
          payloadPos = 73;
          attackPhase = 'blocked';
        } else if (payloadPos >= 100) {
          payloadPos = 100;
          attackPhase = 'encrypting';
          _lastEncryptionStep = elapsed;
        }
      });
    } else if (attackPhase == 'encrypting') {
      if (elapsed - _lastEncryptionStep > const Duration(milliseconds: 250)) {
        _lastEncryptionStep = elapsed;
        final normal = files.where((f) => f.status == 'normal').toList();
        if (normal.isEmpty) {
          setState(() {
            attackPhase = 'ransomed';
          });
        } else {
          setState(() {
            normal[Random().nextInt(normal.length)].status = 'locked';
          });
        }
      }
    } else if (attackPhase == 'restoring') {
      if (elapsed - _lastRestoreStep > const Duration(milliseconds: 100)) {
        _lastRestoreStep = elapsed;
        final locked = files.where((f) => f.status == 'locked').toList();
        if (locked.isEmpty) {
          setState(() {
            attackPhase = 'idle';
          });
        } else {
          setState(() {
            locked[Random().nextInt(locked.length)].status = 'normal';
          });
        }
      }
    }
  }

  void handleStartAttack() {
    setState(() {
      for (var f in files) {
        f.status = 'normal';
      }
      payloadPos = 0;
      attackPhase = 'sending';
    });
  }

  void handleRestore() {
    setState(() {
      attackPhase = 'restoring';
      _lastRestoreStep = Duration.zero;
    });
  }

  void handlePayRansom() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Ransom Payment Attempt',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Payment sent... but the attackers didn\'t send the decryption key!\n\nNever trust cybercriminals. Always enforce secure off-site backups.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Close',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Status text definition
    Color statusColor;
    String statusTitle;
    String statusDesc;

    switch (attackPhase) {
      case 'idle':
        statusColor = const Color(0xFF10B981);
        statusTitle = 'System Normal';
        statusDesc = 'Files are safe. Waiting for simulated network actions.';
        break;
      case 'sending':
        statusColor = const Color(0xFFF59E0B);
        statusTitle = 'Suspicious Email Opened';
        statusDesc =
            'User downloaded an unknown attachment. Initiating script...';
        break;
      case 'blocked':
        statusColor = const Color(0xFF10B981);
        statusTitle = 'Threat Neutralized';
        statusDesc =
            'EDR/Antivirus detected and quarantined the ransomware payload.';
        break;
      case 'encrypting':
        statusColor = const Color(0xFFEF4444);
        statusTitle = 'Encryption in Progress!';
        statusDesc =
            'Malware is locking user files. CPU and Disk activity spiking.';
        break;
      case 'ransomed':
        statusColor = const Color(0xFFEF4444);
        statusTitle = 'System Compromised';
        statusDesc =
            'All files encrypted. Attackers are demanding BTC payment.';
        break;
      case 'restoring':
        statusColor = const Color(0xFF06B6D4);
        statusTitle = 'Restoring from Backup';
        statusDesc =
            'Wiping infected system and recovering clean copies from local vault.';
        break;
      default:
        statusColor = Colors.grey;
        statusTitle = '';
        statusDesc = '';
    }

    final disableAttackBtn = [
      'sending',
      'encrypting',
      'restoring',
    ].contains(attackPhase);
    final disableRestoreBtn = !['ransomed', 'encrypting'].contains(attackPhase);

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 600 / 340,
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: CustomPaint(
              painter: _RansomwarePainter(
                attackPhase: attackPhase,
                edrEnabled: edrEnabled,
                files: files,
                payloadPos: payloadPos,
              ),
            ),
          ),
        ),
        // Controls panel
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(
                          0xFFEF4444,
                        ).withOpacity(0.1),
                        foregroundColor: const Color(0xFFEF4444),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: const BorderSide(color: Color(0xFFEF4444)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: disableAttackBtn ? null : handleStartAttack,
                      child: Text(
                        attackPhase == 'ransomed'
                            ? 'Launch New Attack'
                            : 'Trigger Phishing',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    children: [
                      Text(
                        'EDR / AV',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Switch(
                        value: edrEnabled,
                        activeThumbColor: const Color(0xFF10B981),
                        onChanged: (val) {
                          setState(() {
                            edrEnabled = val;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Disaster Recovery Backup',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    onPressed: disableRestoreBtn ? null : handleRestore,
                    child: Text(
                      'Restore Data',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Status
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: statusColor.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                statusTitle,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                statusDesc,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.8),
                ),
              ),
              if (attackPhase == 'ransomed') ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: handlePayRansom,
                    child: Text(
                      'Attempt to pay ransom?',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFFEF4444),
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ==========================================
// 4. Social Engineering Lab
// ==========================================

class SocialEngineeringLabWidget extends StatefulWidget {
  final bool startMitigated;

  const SocialEngineeringLabWidget({super.key, required this.startMitigated});

  @override
  State<SocialEngineeringLabWidget> createState() =>
      _SocialEngineeringLabWidgetState();
}

class _SocialEngineeringLabWidgetState extends State<SocialEngineeringLabWidget>
    with SingleTickerProviderStateMixin {
  String phase =
      'idle'; // idle, lure, stealing, attacking_vault, mfa_prompt, breached, blocked_training, blocked_mfa
  String attackType = 'phishing';
  late bool trainingEnabled;
  late bool mfaEnabled;
  double animProgress = 0.0;

  Ticker? _ticker;
  Duration _lastElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    trainingEnabled = widget.startMitigated;
    mfaEnabled = widget.startMitigated;
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    final dt = (elapsed - _lastElapsed).inMilliseconds;
    _lastElapsed = elapsed;

    if (['lure', 'stealing', 'attacking_vault', 'mfa_prompt'].contains(phase)) {
      setState(() {
        animProgress += dt * (100.0 / 1200.0); // 1.2 seconds per phase
        if (animProgress >= 100.0) {
          animProgress = 100.0;
          _handlePhaseComplete();
        }
      });
    }
  }

  void _handlePhaseComplete() {
    if (phase == 'lure') {
      if (trainingEnabled) {
        setState(() {
          phase = 'blocked_training';
          animProgress = 100;
        });
      } else {
        setState(() {
          phase = 'stealing';
          animProgress = 0;
        });
      }
    } else if (phase == 'stealing') {
      setState(() {
        phase = 'attacking_vault';
        animProgress = 0;
      });
    } else if (phase == 'attacking_vault') {
      if (mfaEnabled) {
        setState(() {
          phase = 'mfa_prompt';
          animProgress = 0;
        });
      } else {
        setState(() {
          phase = 'breached';
          animProgress = 100;
        });
      }
    } else if (phase == 'mfa_prompt') {
      setState(() {
        phase = 'blocked_mfa';
        animProgress = 100;
      });
    }
  }

  void handleLaunch(String type) {
    setState(() {
      attackType = type;
      animProgress = 0;
      phase = 'lure';
    });
  }

  void resetSim() {
    setState(() {
      phase = 'idle';
      animProgress = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusTitle;
    String statusDesc;

    switch (phase) {
      case 'idle':
        statusColor = const Color(0xFF10B981);
        statusTitle = 'Systems Normal';
        statusDesc = 'Attacker is preparing a social engineering campaign.';
        break;
      case 'lure':
        statusColor = const Color(0xFFF59E0B);
        statusTitle = attackType == 'phishing'
            ? 'Phishing Email Sent'
            : 'Vishing Call Initiated';
        statusDesc =
            'Attacker is using urgency and manipulation to trick the employee.';
        break;
      case 'blocked_training':
        statusColor = const Color(0xFF10B981);
        statusTitle = 'Attack Blocked (Human Firewall)';
        statusDesc =
            'Security awareness training paid off! Employee recognized the lure and reported it.';
        break;
      case 'stealing':
        statusColor = const Color(0xFFF59E0B);
        statusTitle = 'Employee Manipulated';
        statusDesc =
            'The employee fell for the trick and is handing over their password.';
        break;
      case 'attacking_vault':
        statusColor = const Color(0xFFEF4444);
        statusTitle = 'Credentials Stolen';
        statusDesc =
            'Attacker is using the stolen password to access the company vault.';
        break;
      case 'mfa_prompt':
        statusColor = const Color(0xFF06B6D4);
        statusTitle = 'MFA Triggered';
        statusDesc =
            'Vault requires a second factor. Prompt sent to the real employee.';
        break;
      case 'blocked_mfa':
        statusColor = const Color(0xFF10B981);
        statusTitle = 'Attack Blocked (MFA)';
        statusDesc =
            'Employee denied the unexpected MFA prompt. Attacker blocked.';
        break;
      case 'breached':
        statusColor = const Color(0xFFEF4444);
        statusTitle = 'Data Breach!';
        statusDesc =
            'Attacker successfully bypassed all defenses and accessed the vault.';
        break;
      default:
        statusColor = Colors.grey;
        statusTitle = '';
        statusDesc = '';
    }

    final disableAttackBtn = ![
      'idle',
      'breached',
      'blocked_training',
      'blocked_mfa',
    ].contains(phase);

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 600 / 280,
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: CustomPaint(
              painter: _SocialEngineeringPainter(
                phase: phase,
                attackType: attackType,
                trainingEnabled: trainingEnabled,
                mfaEnabled: mfaEnabled,
                animProgress: animProgress,
              ),
            ),
          ),
        ),
        // Controls
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(
                              0xFF3D5CFF,
                            ).withOpacity(0.1),
                            foregroundColor: const Color(0xFF3D5CFF),
                            side: const BorderSide(color: Color(0xFF3D5CFF)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: disableAttackBtn
                              ? null
                              : () => handleLaunch('phishing'),
                          child: Text(
                            'Phishing Email',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(
                              0xFF3D5CFF,
                            ).withOpacity(0.1),
                            foregroundColor: const Color(0xFF3D5CFF),
                            side: const BorderSide(color: Color(0xFF3D5CFF)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: disableAttackBtn
                              ? null
                              : () => handleLaunch('vishing'),
                          child: Text(
                            'Fake CEO Call',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Training   ',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Switch(
                            value: trainingEnabled,
                            activeThumbColor: const Color(0xFF10B981),
                            onChanged: (val) {
                              setState(() {
                                trainingEnabled = val;
                                resetSim();
                              });
                            },
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'MFA           ',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Switch(
                            value: mfaEnabled,
                            activeThumbColor: const Color(0xFF10B981),
                            onChanged: (val) {
                              setState(() {
                                mfaEnabled = val;
                                resetSim();
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              if (!disableAttackBtn && phase != 'idle') ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: resetSim,
                  child: Text(
                    'Reset Simulation',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
        ),
        // Status Banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: statusColor.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                statusTitle,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                statusDesc,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ==========================================
// 5. Insider Threat Lab
// ==========================================

class InsiderThreatLabWidget extends StatefulWidget {
  final bool startMitigated;

  const InsiderThreatLabWidget({super.key, required this.startMitigated});

  @override
  State<InsiderThreatLabWidget> createState() => _InsiderThreatLabWidgetState();
}

class _InsiderThreatLabWidgetState extends State<InsiderThreatLabWidget>
    with SingleTickerProviderStateMixin {
  String phase =
      'idle'; // idle, gathering, exfiltrating, breached, blocked_ueba, blocked_dlp
  String attackType = 'usb';
  late bool uebaEnabled;
  late bool dlpEnabled;
  double animProgress = 0.0;

  Ticker? _ticker;
  Duration _lastElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    uebaEnabled = widget.startMitigated;
    dlpEnabled = widget.startMitigated;
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    final dt = (elapsed - _lastElapsed).inMilliseconds;
    _lastElapsed = elapsed;

    if (['gathering', 'exfiltrating'].contains(phase)) {
      setState(() {
        animProgress += dt * (100.0 / 1200.0); // 1.2s per phase
        if (animProgress >= 100.0) {
          animProgress = 100.0;
          _handlePhaseComplete();
        }
      });
    }
  }

  void _handlePhaseComplete() {
    if (phase == 'gathering') {
      if (uebaEnabled) {
        setState(() {
          phase = 'blocked_ueba';
          animProgress = 100;
        });
      } else {
        setState(() {
          phase = 'exfiltrating';
          animProgress = 0;
        });
      }
    } else if (phase == 'exfiltrating') {
      if (dlpEnabled) {
        setState(() {
          phase = 'blocked_dlp';
          animProgress = 100;
        });
      } else {
        setState(() {
          phase = 'breached';
          animProgress = 100;
        });
      }
    }
  }

  void handleLaunch(String type) {
    setState(() {
      attackType = type;
      animProgress = 0;
      phase = 'gathering';
    });
  }

  void resetSim() {
    setState(() {
      phase = 'idle';
      animProgress = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusTitle;
    String statusDesc;

    switch (phase) {
      case 'idle':
        statusColor = const Color(0xFF10B981);
        statusTitle = 'Systems Normal';
        statusDesc = 'Employee is working. No anomalous activity detected.';
        break;
      case 'gathering':
        statusColor = const Color(0xFFF59E0B);
        statusTitle = 'Data Hoarding Detected';
        statusDesc =
            'Rogue employee is downloading a massive amount of sensitive data to local machine.';
        break;
      case 'blocked_ueba':
        statusColor = const Color(0xFF10B981);
        statusTitle = 'Attack Blocked (UEBA)';
        statusDesc =
            'Behavioral analytics detected the download spike and suspended account immediately.';
        break;
      case 'exfiltrating':
        statusColor = const Color(0xFFF59E0B);
        statusTitle = attackType == 'usb'
            ? 'USB Exfiltration in Progress'
            : 'Cloud Exfiltration in Progress';
        statusDesc =
            'Employee is attempting to transfer stolen data outside the perimeter.';
        break;
      case 'blocked_dlp':
        statusColor = const Color(0xFF10B981);
        statusTitle = 'Attack Blocked (DLP)';
        statusDesc =
            'Data Loss Prevention intercepted the file transfer to unauthorized device/cloud.';
        break;
      case 'breached':
        statusColor = const Color(0xFFEF4444);
        statusTitle = 'Data Exfiltrated!';
        statusDesc =
            'The rogue insider successfully copied and moved secret company data off-site.';
        break;
      default:
        statusColor = Colors.grey;
        statusTitle = '';
        statusDesc = '';
    }

    final disableAttackBtn = ![
      'idle',
      'breached',
      'blocked_ueba',
      'blocked_dlp',
    ].contains(phase);

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 600 / 280,
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: CustomPaint(
              painter: _InsiderThreatPainter(
                phase: phase,
                attackType: attackType,
                uebaEnabled: uebaEnabled,
                dlpEnabled: dlpEnabled,
                animProgress: animProgress,
              ),
            ),
          ),
        ),
        // Controls
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(
                              0xFF3D5CFF,
                            ).withOpacity(0.1),
                            foregroundColor: const Color(0xFF3D5CFF),
                            side: const BorderSide(color: Color(0xFF3D5CFF)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: disableAttackBtn
                              ? null
                              : () => handleLaunch('usb'),
                          child: Text(
                            'USB Copy',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(
                              0xFF3D5CFF,
                            ).withOpacity(0.1),
                            foregroundColor: const Color(0xFF3D5CFF),
                            side: const BorderSide(color: Color(0xFF3D5CFF)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: disableAttackBtn
                              ? null
                              : () => handleLaunch('cloud'),
                          child: Text(
                            'Cloud Upload',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'UEBA (Analytics) ',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Switch(
                            value: uebaEnabled,
                            activeThumbColor: const Color(0xFF10B981),
                            onChanged: (val) {
                              setState(() {
                                uebaEnabled = val;
                                resetSim();
                              });
                            },
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'DLP (Perimeter)   ',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Switch(
                            value: dlpEnabled,
                            activeThumbColor: const Color(0xFF10B981),
                            onChanged: (val) {
                              setState(() {
                                dlpEnabled = val;
                                resetSim();
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              if (!disableAttackBtn && phase != 'idle') ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: resetSim,
                  child: Text(
                    'Reset Simulation',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
        ),
        // Status Banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: statusColor.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                statusTitle,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                statusDesc,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Painters classes

class _DosPainter extends CustomPainter {
  final double requestLevel;
  final bool firewallEnabled;
  final List<_DosRequestParticle> requests;
  final String status;

  _DosPainter({
    required this.requestLevel,
    required this.firewallEnabled,
    required this.requests,
    required this.status,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 550.0;
    final scaleY = size.height / 440.0;
    canvas.scale(scaleX, scaleY);

    final linePaintAttacker = Paint()
      ..color = const Color(0xFFEF4444).withOpacity(0.6)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    _drawDashedLine(
      canvas,
      const Offset(80, 100),
      const Offset(335, 222),
      Colors.grey.withOpacity(0.5),
    );
    _drawDashedLine(
      canvas,
      const Offset(80, 400),
      const Offset(335, 278),
      Colors.grey.withOpacity(0.5),
    );

    final targetR = status == 'protected' ? 80.0 + 25.0 : 45.0 + 4.0;
    final angle = atan2(250.0 - 250.0, 380.0 - 80.0);
    final tx = 380.0 - targetR * cos(angle);
    final ty = 250.0 - targetR * sin(angle);
    canvas.drawLine(const Offset(80, 250), Offset(tx, ty), linePaintAttacker);

    if (status == 'protected') {
      final shieldPaint = Paint()
        ..color = const Color(0xFF10B981)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      final shieldAuraPaint = Paint()
        ..color = const Color(0xFF10B981).withOpacity(0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20.0;

      final rect = Rect.fromCircle(
        center: const Offset(380, 250),
        radius: 80.0,
      );
      canvas.drawArc(rect, pi / 2 + 0.1, pi - 0.2, false, shieldAuraPaint);
      canvas.drawArc(rect, pi / 2 + 0.1, pi - 0.2, false, shieldPaint);

      final outerRect = Rect.fromCircle(
        center: const Offset(380, 250),
        radius: 90.0,
      );
      _drawDashedArc(canvas, outerRect, pi / 2 + 0.2, pi - 0.4, shieldPaint);

      final textPainter = TextPainter(
        text: const TextSpan(
          text: 'IP FILTER',
          style: TextStyle(
            color: Color(0xFF10B981),
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(
          380.0 - 80.0 - textPainter.width / 2 - 10,
          250.0 - textPainter.height / 2,
        ),
      );
    }

    final serverPaint = Paint()
      ..color = status == 'crashing'
          ? const Color(0xFFEF4444)
          : const Color(0xFF1E1E38)
      ..style = PaintingStyle.fill;

    final serverBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    var shakeX = 0.0;
    var shakeY = 0.0;
    if (status == 'crashing') {
      final rand = Random();
      shakeX = (rand.nextDouble() - 0.5) * 6.0;
      shakeY = (rand.nextDouble() - 0.5) * 6.0;
    }

    final serverCenter = Offset(380.0 + shakeX, 250.0 + shakeY);
    canvas.drawCircle(serverCenter, 45.0, serverPaint);
    canvas.drawCircle(serverCenter, 45.0, serverBorderPaint);

    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'SERVER',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      serverCenter - Offset(textPainter.width / 2, textPainter.height / 2),
    );

    _drawClientNode(canvas, const Offset(80, 100), 'USER', Colors.white);
    _drawClientNode(
      canvas,
      const Offset(80, 250),
      'ATTACKER',
      const Color(0xFFEF4444),
    );
    _drawClientNode(canvas, const Offset(80, 400), 'USER', Colors.white);

    for (final req in requests) {
      final x = req.startX + (req.targetX - req.startX) * req.progress;
      final y = req.startY + (req.targetY - req.startY) * req.progress;
      var radius = 4.0;
      var color = req.type == 'attacker'
          ? const Color(0xFFEF4444)
          : const Color(0xFF3D5CFF);

      if (req.progress >= 0.9) {
        if (req.type == 'attacker') {
          if (status == 'crashing' || status == 'protected') {
            radius = 4.0 + (req.progress - 0.9) * 40.0;
            color = color.withOpacity((1.0 - req.progress).clamp(0.0, 1.0));
          }
        } else {
          if (status == 'crashing') {
            radius = 4.0 * (1.0 - (req.progress - 0.9) * 10);
            color = Colors.grey.withOpacity(
              (1.0 - (req.progress - 0.9) * 10).clamp(0.0, 1.0),
            );
          }
        }
      }

      final pPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), radius, pPaint);
    }
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    const dashWidth = 6.0;
    const dashSpace = 4.0;
    final distance = (p2 - p1).distance;
    final angle = atan2(p2.dy - p1.dy, p2.dx - p1.dx);
    var currentDist = 0.0;
    while (currentDist < distance) {
      final x1 = p1.dx + currentDist * cos(angle);
      final y1 = p1.dy + currentDist * sin(angle);
      currentDist += dashWidth;
      final x2 =
          p1.dx +
          (currentDist < distance ? currentDist : distance) * cos(angle);
      final y2 =
          p1.dy +
          (currentDist < distance ? currentDist : distance) * sin(angle);
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
      currentDist += dashSpace;
    }
  }

  void _drawDashedArc(
    Canvas canvas,
    Rect rect,
    double startAngle,
    double sweepAngle,
    Paint paint,
  ) {
    const dashAngle = 0.08;
    const spaceAngle = 0.06;
    var currentAngle = startAngle;
    final endAngle = startAngle + sweepAngle;
    while (currentAngle < endAngle) {
      final sweep = (currentAngle + dashAngle < endAngle)
          ? dashAngle
          : (endAngle - currentAngle);
      canvas.drawArc(rect, currentAngle, sweep, false, paint);
      currentAngle += dashAngle + spaceAngle;
    }
  }

  void _drawClientNode(Canvas canvas, Offset pos, String label, Color color) {
    final screenPaint = Paint()
      ..color = const Color(0xFF1E1E38)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final rect = Rect.fromCenter(
      center: pos + const Offset(0, -2),
      width: 28,
      height: 18,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(2)),
      screenPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(2)),
      borderPaint,
    );

    canvas.drawLine(
      pos + const Offset(-18, 11),
      pos + const Offset(18, 11),
      borderPaint,
    );
    canvas.drawLine(
      pos + const Offset(-5, 7),
      pos + const Offset(-5, 11),
      borderPaint,
    );
    canvas.drawLine(
      pos + const Offset(5, 7),
      pos + const Offset(5, 11),
      borderPaint,
    );

    if (label == 'ATTACKER') {
      final xPaint = Paint()
        ..color = color
        ..strokeWidth = 1.2;
      canvas.drawLine(
        pos + const Offset(-8, -6),
        pos + const Offset(-4, -2),
        xPaint,
      );
      canvas.drawLine(
        pos + const Offset(-4, -6),
        pos + const Offset(-8, -2),
        xPaint,
      );
      canvas.drawLine(
        pos + const Offset(4, -6),
        pos + const Offset(8, -2),
        xPaint,
      );
      canvas.drawLine(
        pos + const Offset(8, -6),
        pos + const Offset(4, -2),
        xPaint,
      );
      canvas.drawLine(
        pos + const Offset(-6, 4),
        pos + const Offset(-3, 2),
        xPaint,
      );
      canvas.drawLine(
        pos + const Offset(-3, 2),
        pos + const Offset(0, 4),
        xPaint,
      );
      canvas.drawLine(
        pos + const Offset(0, 4),
        pos + const Offset(3, 2),
        xPaint,
      );
      canvas.drawLine(
        pos + const Offset(3, 2),
        pos + const Offset(6, 4),
        xPaint,
      );
    }

    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, pos + Offset(-textPainter.width / 2, 20));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _DdosPainter extends CustomPainter {
  final double requestLevel;
  final bool firewallEnabled;
  final List<_DdosRequestParticle> externalRequests;
  final List<_DdosRequestParticle> internalRequests;
  final String status;

  _DdosPainter({
    required this.requestLevel,
    required this.firewallEnabled,
    required this.externalRequests,
    required this.internalRequests,
    required this.status,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 500.0;
    final scaleY = size.height / 500.0;
    canvas.scale(scaleX, scaleY);

    const center = 250.0;
    const orbitRadius = 190.0;
    const serverRadius = 45.0;
    const shieldOuterRadius = 75.0;
    const shieldInnerRadius = 55.0;

    final orbitPaint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawCircle(const Offset(center, center), orbitRadius, orbitPaint);

    final numClients = (4 + (requestLevel / 100.0) * 28).floor();
    final clients = getClients(numClients, requestLevel);

    for (final client in clients) {
      final isRedLine = status == 'crashing' ? true : client.isRedBase;
      final color = isRedLine
          ? const Color(0xFFEF4444)
          : Colors.grey.withOpacity(0.4);
      final linePaint = Paint()
        ..color = color
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;

      final targetRadius = status == 'protected'
          ? shieldOuterRadius
          : serverRadius + 4;
      final tx = center + targetRadius * cos(client.angle);
      final ty = center + targetRadius * sin(client.angle);

      canvas.drawLine(Offset(client.cx, client.cy), Offset(tx, ty), linePaint);
    }

    if (status == 'protected') {
      for (int i = 0; i < 8; i++) {
        final angle = (i / 8) * 2 * pi;
        final x1 = center + shieldInnerRadius * cos(angle);
        final y1 = center + shieldInnerRadius * sin(angle);
        final x2 = center + (serverRadius + 4) * cos(angle);
        final y2 = center + (serverRadius + 4) * sin(angle);
        _drawDashedLine(
          canvas,
          Offset(x1, y1),
          Offset(x2, y2),
          const Color(0xFF3D5CFF).withOpacity(0.6),
        );
      }
    }

    if (status == 'protected') {
      final shieldPaint = Paint()
        ..color = const Color(0xFF10B981)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      final shieldAuraPaint = Paint()
        ..color = const Color(0xFF10B981).withOpacity(0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20.0;

      canvas.drawCircle(const Offset(center, center), 65.0, shieldAuraPaint);
      canvas.drawCircle(
        const Offset(center, center),
        shieldInnerRadius,
        shieldPaint,
      );

      final outerRect = Rect.fromCircle(
        center: const Offset(center, center),
        radius: shieldOuterRadius,
      );
      _drawDashedArc(canvas, outerRect, 0, 2 * pi, shieldPaint);

      final nodePaint = Paint()..color = const Color(0xFF10B981);
      for (int i = 0; i < 16; i++) {
        final angle = (i / 16) * 2 * pi;
        final cx = center + 65.0 * cos(angle);
        final cy = center + 65.0 * sin(angle);
        canvas.drawCircle(Offset(cx, cy), 2.0, nodePaint);
      }
    }

    final serverPaint = Paint()
      ..color = status == 'crashing'
          ? const Color(0xFFEF4444)
          : const Color(0xFF1E1E38)
      ..style = PaintingStyle.fill;
    final serverBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    var shakeX = 0.0;
    var shakeY = 0.0;
    if (status == 'crashing') {
      final rand = Random();
      shakeX = (rand.nextDouble() - 0.5) * 6.0;
      shakeY = (rand.nextDouble() - 0.5) * 6.0;
    }

    final serverCenter = Offset(center + shakeX, center + shakeY);
    canvas.drawCircle(serverCenter, serverRadius, serverPaint);
    canvas.drawCircle(serverCenter, serverRadius, serverBorderPaint);

    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'Server',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      serverCenter - Offset(textPainter.width / 2, textPainter.height / 2),
    );

    for (final req in externalRequests) {
      final x = req.startX + (req.targetX - req.startX) * req.progress;
      final y = req.startY + (req.targetY - req.startY) * req.progress;
      var radius = 4.5;
      var color = req.isRed ? const Color(0xFFEF4444) : const Color(0xFF3D5CFF);

      if (req.progress >= 0.9) {
        if (req.isRed || status != 'protected') {
          radius = 4.5 + (req.progress - 0.9) * 30.0;
          color = color.withOpacity((1.0 - req.progress).clamp(0.0, 1.0));
        } else {
          radius = 4.5 * (1.0 - (req.progress - 0.9) * 10);
        }
      }

      final pPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), radius, pPaint);
    }

    if (status == 'protected') {
      for (final req in internalRequests) {
        final x = req.startX + (req.targetX - req.startX) * req.progress;
        final y = req.startY + (req.targetY - req.startY) * req.progress;
        final radius = 3.5 * (1.0 - req.progress * 0.5);
        final pPaint = Paint()
          ..color = const Color(0xFF3D5CFF)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(x, y), radius, pPaint);
      }
    }

    for (final client in clients) {
      final isZombie = status == 'crashing' ? true : client.isRedBase;
      _drawClientNode(
        canvas,
        Offset(client.cx, client.cy),
        isZombie ? const Color(0xFFEF4444) : Colors.white,
      );
    }
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0;
    const dashWidth = 4.0;
    const dashSpace = 2.0;
    final distance = (p2 - p1).distance;
    final angle = atan2(p2.dy - p1.dy, p2.dx - p1.dx);
    var currentDist = 0.0;
    while (currentDist < distance) {
      final x1 = p1.dx + currentDist * cos(angle);
      final y1 = p1.dy + currentDist * sin(angle);
      currentDist += dashWidth;
      final x2 =
          p1.dx +
          (currentDist < distance ? currentDist : distance) * cos(angle);
      final y2 =
          p1.dy +
          (currentDist < distance ? currentDist : distance) * sin(angle);
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
      currentDist += dashSpace;
    }
  }

  void _drawDashedArc(
    Canvas canvas,
    Rect rect,
    double startAngle,
    double sweepAngle,
    Paint paint,
  ) {
    const dashAngle = 0.06;
    const spaceAngle = 0.04;
    var currentAngle = startAngle;
    final endAngle = startAngle + sweepAngle;
    while (currentAngle < endAngle) {
      final sweep = (currentAngle + dashAngle < endAngle)
          ? dashAngle
          : (endAngle - currentAngle);
      canvas.drawArc(rect, currentAngle, sweep, false, paint);
      currentAngle += dashAngle + spaceAngle;
    }
  }

  void _drawClientNode(Canvas canvas, Offset pos, Color color) {
    final screenPaint = Paint()
      ..color = const Color(0xFF1E1E38)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    final rect = Rect.fromCenter(
      center: pos + const Offset(0, -2),
      width: 20,
      height: 13,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(2)),
      screenPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(2)),
      borderPaint,
    );

    canvas.drawLine(
      pos + const Offset(-13, 8),
      pos + const Offset(13, 8),
      borderPaint,
    );
    canvas.drawLine(
      pos + const Offset(-3, 5),
      pos + const Offset(-3, 8),
      borderPaint,
    );
    canvas.drawLine(
      pos + const Offset(3, 5),
      pos + const Offset(3, 8),
      borderPaint,
    );

    if (color == const Color(0xFFEF4444)) {
      final xPaint = Paint()
        ..color = color
        ..strokeWidth = 0.8;
      canvas.drawLine(
        pos + const Offset(-6, -5),
        pos + const Offset(-3, -2),
        xPaint,
      );
      canvas.drawLine(
        pos + const Offset(-3, -5),
        pos + const Offset(-6, -2),
        xPaint,
      );
      canvas.drawLine(
        pos + const Offset(3, -5),
        pos + const Offset(6, -2),
        xPaint,
      );
      canvas.drawLine(
        pos + const Offset(6, -5),
        pos + const Offset(3, -2),
        xPaint,
      );
      canvas.drawLine(
        pos + const Offset(-4, 3),
        pos + const Offset(-2, 1),
        xPaint,
      );
      canvas.drawLine(
        pos + const Offset(-2, 1),
        pos + const Offset(0, 3),
        xPaint,
      );
      canvas.drawLine(
        pos + const Offset(0, 3),
        pos + const Offset(2, 1),
        xPaint,
      );
      canvas.drawLine(
        pos + const Offset(2, 1),
        pos + const Offset(4, 3),
        xPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _RansomwarePainter extends CustomPainter {
  final String attackPhase;
  final bool edrEnabled;
  final List<_RansomwareFile> files;
  final double payloadPos;

  _RansomwarePainter({
    required this.attackPhase,
    required this.edrEnabled,
    required this.files,
    required this.payloadPos,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 600.0;
    final scaleY = size.height / 340.0;
    canvas.scale(scaleX, scaleY);

    const hackerCenter = Offset(95.0, 175.0);
    const pcCenter = Offset(435.0, 175.0);

    _drawDashedLine(
      canvas,
      hackerCenter,
      pcCenter,
      Colors.grey.withOpacity(0.5),
    );
    _drawThreatNode(canvas, hackerCenter);

    if (edrEnabled) {
      final shieldPaint = Paint()
        ..color = const Color(0xFF10B981)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;
      final shieldAura1Paint = Paint()
        ..color = const Color(0xFF10B981).withOpacity(0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16.0;
      final shieldAura2Paint = Paint()
        ..color = const Color(0xFF10B981).withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8.0;

      final path = Path()
        ..moveTo(pcCenter.dx - 140, pcCenter.dy - 105)
        ..quadraticBezierTo(
          pcCenter.dx - 165,
          pcCenter.dy,
          pcCenter.dx - 140,
          pcCenter.dy + 105,
        );

      canvas.drawPath(path, shieldAura1Paint);
      canvas.drawPath(path, shieldAura2Paint);
      canvas.drawPath(path, shieldPaint);

      final textPainter = TextPainter(
        text: const TextSpan(
          text: 'EDR ACTIVE',
          style: TextStyle(
            color: Color(0xFF10B981),
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(pcCenter.dx - 152 - textPainter.width / 2, pcCenter.dy - 125),
      );
    }

    _drawTargetPC(canvas, pcCenter);

    if (attackPhase == 'sending') {
      final payloadX =
          hackerCenter.dx +
          ((pcCenter.dx - 100 - hackerCenter.dx) * (payloadPos / 100.0));
      _drawPayload(canvas, Offset(payloadX, hackerCenter.dy));
    }
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0;
    const dashWidth = 8.0;
    const dashSpace = 6.0;
    final distance = (p2 - p1).distance;
    final angle = atan2(p2.dy - p1.dy, p2.dx - p1.dx);
    var currentDist = 0.0;
    while (currentDist < distance) {
      final x1 = p1.dx + currentDist * cos(angle);
      final y1 = p1.dy + currentDist * sin(angle);
      currentDist += dashWidth;
      final x2 =
          p1.dx +
          (currentDist < distance ? currentDist : distance) * cos(angle);
      final y2 =
          p1.dy +
          (currentDist < distance ? currentDist : distance) * sin(angle);
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
      currentDist += dashSpace;
    }
  }

  void _drawThreatNode(Canvas canvas, Offset center) {
    final rect = Rect.fromCenter(center: center, width: 60, height: 70);
    final bgPaint = Paint()..color = const Color(0xFF1E1E38);
    final borderPaint = Paint()
      ..color = const Color(0xFFEF4444)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      bgPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      borderPaint,
    );

    final facePaint = Paint()..color = const Color(0xFFEF4444);
    canvas.drawCircle(center + const Offset(0, -10), 12.0, facePaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center + const Offset(0, 7),
          width: 16,
          height: 10,
        ),
        const Radius.circular(2),
      ),
      facePaint,
    );

    final eyePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0;
    canvas.drawLine(
      center + const Offset(-6, -10),
      center + const Offset(-2, -10),
      eyePaint,
    );
    canvas.drawLine(
      center + const Offset(2, -10),
      center + const Offset(6, -10),
      eyePaint,
    );

    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'THREAT',
        style: TextStyle(
          color: Color(0xFFEF4444),
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, center + Offset(-textPainter.width / 2, 22));
  }

  void _drawTargetPC(Canvas canvas, Offset center) {
    var shakeX = 0.0;
    var shakeY = 0.0;
    if (attackPhase == 'encrypting') {
      final rand = Random();
      shakeX = (rand.nextDouble() - 0.5) * 4.0;
      shakeY = (rand.nextDouble() - 0.5) * 4.0;
    }

    final pcPos = center + Offset(shakeX, shakeY);

    final framePaint = Paint()..color = const Color(0xFF1F1F39);
    final borderPaint = Paint()
      ..color = Colors.grey.withOpacity(0.6)
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;

    final frameRect = Rect.fromCenter(
      center: pcPos + const Offset(0, -30),
      width: 200,
      height: 180,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(frameRect, const Radius.circular(12)),
      framePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(frameRect, const Radius.circular(12)),
      borderPaint,
    );

    final screenPaint = Paint()..color = const Color(0xFF161632);
    final screenBorderPaint = Paint()
      ..color = Colors.grey.withOpacity(0.4)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    final screenRect = Rect.fromCenter(
      center: pcPos + const Offset(0, -30),
      width: 180,
      height: 160,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(screenRect, const Radius.circular(4)),
      screenPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(screenRect, const Radius.circular(4)),
      screenBorderPaint,
    );

    final standPaint = Paint()..color = Colors.grey.withOpacity(0.6);
    final standPath = Path()
      ..moveTo(pcPos.dx - 20, pcPos.dy + 60)
      ..lineTo(pcPos.dx + 20, pcPos.dy + 60)
      ..lineTo(pcPos.dx + 30, pcPos.dy + 100)
      ..lineTo(pcPos.dx - 30, pcPos.dy + 100)
      ..close();
    canvas.drawPath(standPath, standPaint);

    final baseRect = Rect.fromCenter(
      center: pcPos + const Offset(0, 104),
      width: 100,
      height: 8,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(baseRect, const Radius.circular(4)),
      standPaint,
    );

    final fileNormalPaint = Paint()..color = const Color(0xFF3D5CFF);
    final fileLockedPaint = Paint()..color = const Color(0xFFEF4444);

    final gridStart = pcPos + const Offset(-90 + 20, -110 + 20);

    for (int i = 0; i < files.length; i++) {
      final row = i ~/ 4;
      final col = i % 4;
      final x = gridStart.dx + col * 38.0;
      final y = gridStart.dy + row * 45.0;
      final isLocked = files[i].status == 'locked';

      final fileRect = Rect.fromLTWH(x, y, 18, 24);
      final filePaint = isLocked ? fileLockedPaint : fileNormalPaint;
      canvas.drawRect(fileRect, filePaint);

      final foldPath = Path()
        ..moveTo(x + 12, y)
        ..lineTo(x + 18, y)
        ..lineTo(x + 18, y + 6)
        ..close();
      canvas.drawPath(foldPath, Paint()..color = Colors.black.withOpacity(0.3));

      if (isLocked) {
        final lockPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x + 4, y + 12, 10, 8),
            const Radius.circular(1),
          ),
          lockPaint,
        );
        final shacklePaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawArc(
          Rect.fromLTWH(x + 6, y + 8, 6, 6),
          pi,
          pi,
          false,
          shacklePaint,
        );
      } else {
        final linePaint = Paint()
          ..color = Colors.white.withOpacity(0.6)
          ..strokeWidth = 1.5;
        canvas.drawLine(
          Offset(x + 3, y + 10),
          Offset(x + 15, y + 10),
          linePaint,
        );
        canvas.drawLine(
          Offset(x + 3, y + 14),
          Offset(x + 12, y + 14),
          linePaint,
        );
        canvas.drawLine(
          Offset(x + 3, y + 18),
          Offset(x + 15, y + 18),
          linePaint,
        );
      }
    }

    if (attackPhase == 'ransomed') {
      final lockScreenPaint = Paint()
        ..color = const Color(0xFFEF4444).withOpacity(0.95);
      canvas.drawRRect(
        RRect.fromRectAndRadius(screenRect, const Radius.circular(4)),
        lockScreenPaint,
      );

      final titlePainter = TextPainter(
        text: const TextSpan(
          text: 'SYSTEM LOCKED',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      titlePainter.paint(canvas, pcPos + Offset(-titlePainter.width / 2, -90));

      final descPainter = TextPainter(
        text: const TextSpan(
          text:
              'Your files are encrypted.\nSend 2.5 BTC to:\n1A1zP1eP5QGefi2DMPTfTL5SL...',
          style: TextStyle(color: Colors.white, fontSize: 8, height: 1.3),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();
      descPainter.paint(canvas, pcPos + Offset(-descPainter.width / 2, -65));

      final btnPaint = Paint()
        ..color = Colors.white.withOpacity(0.2)
        ..style = PaintingStyle.fill;
      final btnBorderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      final btnRect = Rect.fromCenter(
        center: pcPos + const Offset(0, 15),
        width: 110,
        height: 20,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(btnRect, const Radius.circular(4)),
        btnPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(btnRect, const Radius.circular(4)),
        btnBorderPaint,
      );

      final btnTextPainter = TextPainter(
        text: const TextSpan(
          text: 'DECRYPT FILES',
          style: TextStyle(
            color: Colors.white,
            fontSize: 8,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      btnTextPainter.paint(
        canvas,
        pcPos + Offset(-btnTextPainter.width / 2, 10),
      );
    }
  }

  void _drawPayload(Canvas canvas, Offset pos) {
    final rect = Rect.fromCenter(center: pos, width: 30, height: 20);
    final bgPaint = Paint()..color = const Color(0xFF1E1E38);
    final borderPaint = Paint()
      ..color = const Color(0xFFEF4444)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(2)),
      bgPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(2)),
      borderPaint,
    );

    final flapPath = Path()
      ..moveTo(pos.dx - 15, pos.dy - 10)
      ..lineTo(pos.dx, pos.dy)
      ..lineTo(pos.dx + 15, pos.dy - 10);
    canvas.drawPath(flapPath, borderPaint);

    final badgePaint = Paint()..color = const Color(0xFFEF4444);
    canvas.drawCircle(pos + const Offset(13, -8), 5.0, badgePaint);

    final markPainter = TextPainter(
      text: const TextSpan(
        text: '!',
        style: TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    markPainter.paint(
      canvas,
      pos + Offset(13 - markPainter.width / 2, -8 - markPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _SocialEngineeringPainter extends CustomPainter {
  final String phase;
  final String attackType;
  final bool trainingEnabled;
  final bool mfaEnabled;
  final double animProgress;

  _SocialEngineeringPainter({
    required this.phase,
    required this.attackType,
    required this.trainingEnabled,
    required this.mfaEnabled,
    required this.animProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 600.0;
    final scaleY = size.height / 280.0;
    canvas.scale(scaleX, scaleY);

    const hackerCenter = Offset(80.0, 180.0);
    const empCenter = Offset(300.0, 180.0);
    const vaultCenter = Offset(520.0, 180.0);

    const userAvatarX = 255.0;
    const pcX = 345.0;

    final linePaintLight = Paint()
      ..color = Colors.grey.withOpacity(0.3)
      ..strokeWidth = 2.0;

    final linePaintMain = Paint()
      ..color = Colors.grey.withOpacity(0.6)
      ..strokeWidth = 2.0;

    _drawDashedLine(
      canvas,
      hackerCenter + const Offset(30, 0),
      const Offset(userAvatarX - 14, 180),
      Colors.grey.withOpacity(0.4),
    );
    canvas.drawLine(
      const Offset(userAvatarX + 14, 180),
      const Offset(pcX - 24, 180),
      linePaintLight,
    );
    canvas.drawLine(
      const Offset(pcX + 24, 180),
      Offset(vaultCenter.dx - 30, 180),
      linePaintMain,
    );

    final p0 = Offset(hackerCenter.dx, hackerCenter.dy - 35);
    final p1 = Offset(empCenter.dx, 20.0);
    final p2 = Offset(vaultCenter.dx, vaultCenter.dy - 45);
    if ([
      'attacking_vault',
      'breached',
      'mfa_prompt',
      'blocked_mfa',
    ].contains(phase)) {
      final archPaint = Paint()
        ..color = const Color(0xFFEF4444).withOpacity(0.3)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      final path = Path()
        ..moveTo(p0.dx, p0.dy)
        ..quadraticBezierTo(p1.dx, p1.dy, p2.dx, p2.dy);
      _drawDashedPath(canvas, path, archPaint);
    }

    _drawHackerNode(canvas, hackerCenter);
    _drawEmployeeNode(canvas, const Offset(userAvatarX, 180));
    _drawPCNode(canvas, const Offset(pcX, 180));
    _drawVaultNode(canvas, vaultCenter);

    final t = animProgress / 100.0;

    if (phase == 'lure' || phase == 'blocked_training') {
      const startX = 80.0 + 30.0 + 14.0;
      const endX = userAvatarX - 14.0 - 14.0;
      final targetEndX = trainingEnabled ? (userAvatarX - 32.0) : endX;
      final x = phase == 'blocked_training'
          ? targetEndX
          : startX + (targetEndX - startX) * t;

      _drawLurePayload(canvas, Offset(x, 180.0), phase == 'blocked_training');
    }

    if (phase == 'stealing') {
      const startX = userAvatarX - 14.0 - 14.0;
      const endX = 80.0 + 30.0 + 14.0;
      final x = startX - (startX - endX) * t;
      _drawPasswordPayload(canvas, Offset(x, 180.0));
    }

    if (phase == 'attacking_vault') {
      final x =
          pow(1 - t, 2) * p0.dx + 2 * (1 - t) * t * p1.dx + pow(t, 2) * p2.dx;
      final y =
          pow(1 - t, 2) * p0.dy + 2 * (1 - t) * t * p1.dy + pow(t, 2) * p2.dy;
      _drawPasswordPayload(canvas, Offset(x, y));
    }

    if (phase == 'mfa_prompt') {
      final startX = vaultCenter.dx - 30.0 - 10.0;
      const endX = pcX + 24.0 + 10.0;
      final x = startX - (startX - endX) * t;
      _drawMfaPayload(canvas, Offset(x, 180.0));
    }
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    const dashWidth = 6.0;
    const dashSpace = 4.0;
    final distance = (p2 - p1).distance;
    final angle = atan2(p2.dy - p1.dy, p2.dx - p1.dx);
    var currentDist = 0.0;
    while (currentDist < distance) {
      final x1 = p1.dx + currentDist * cos(angle);
      final y1 = p1.dy + currentDist * sin(angle);
      currentDist += dashWidth;
      final x2 =
          p1.dx +
          (currentDist < distance ? currentDist : distance) * cos(angle);
      final y2 =
          p1.dy +
          (currentDist < distance ? currentDist : distance) * sin(angle);
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
      currentDist += dashSpace;
    }
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    final metrics = path.computeMetrics();
    const dashWidth = 8.0;
    const dashSpace = 4.0;
    for (final metric in metrics) {
      var currentDist = 0.0;
      while (currentDist < metric.length) {
        final nextDist = (currentDist + dashWidth < metric.length)
            ? (currentDist + dashWidth)
            : metric.length;
        canvas.drawPath(metric.extractPath(currentDist, nextDist), paint);
        currentDist = nextDist + dashSpace;
      }
    }
  }

  void _drawHackerNode(Canvas canvas, Offset center) {
    final rect = Rect.fromCenter(center: center, width: 60, height: 70);
    final bgPaint = Paint()..color = const Color(0xFF1E1E38);
    final borderPaint = Paint()
      ..color = const Color(0xFFEF4444)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      bgPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      borderPaint,
    );

    final facePaint = Paint()..color = const Color(0xFFEF4444);
    canvas.drawCircle(center + const Offset(0, -10), 12.0, facePaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center + const Offset(0, 7),
          width: 16,
          height: 10,
        ),
        const Radius.circular(2),
      ),
      facePaint,
    );

    final eyePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0;
    canvas.drawLine(
      center + const Offset(-6, -10),
      center + const Offset(-2, -10),
      eyePaint,
    );
    canvas.drawLine(
      center + const Offset(2, -10),
      center + const Offset(6, -10),
      eyePaint,
    );

    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'ATTACKER',
        style: TextStyle(
          color: Color(0xFFEF4444),
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, center + Offset(-textPainter.width / 2, 22));
  }

  void _drawEmployeeNode(Canvas canvas, Offset pos) {
    final avatarPaint = Paint()
      ..color = trainingEnabled
          ? const Color(0xFF10B981)
          : Colors.grey.shade400;

    canvas.drawCircle(pos + const Offset(0, -2), 14.0, avatarPaint);

    final bodyPath = Path()
      ..moveTo(pos.dx - 22, pos.dy + 28)
      ..quadraticBezierTo(pos.dx - 22, pos.dy + 3, pos.dx, pos.dy + 3)
      ..quadraticBezierTo(pos.dx + 22, pos.dy + 3, pos.dx + 22, pos.dy + 28)
      ..close();
    canvas.drawPath(bodyPath, avatarPaint);

    if (trainingEnabled) {
      final glassPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(pos.dx - 9, pos.dy - 6, 7, 5),
          const Radius.circular(1),
        ),
        glassPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(pos.dx + 2, pos.dy - 6, 7, 5),
          const Radius.circular(1),
        ),
        glassPaint,
      );

      final framePaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 1.5;
      canvas.drawLine(
        pos + const Offset(-2, -3.5),
        pos + const Offset(2, -3.5),
        framePaint,
      );
      canvas.drawLine(
        pos + const Offset(-12, -3.5),
        pos + const Offset(-9, -3.5),
        framePaint,
      );
      canvas.drawLine(
        pos + const Offset(9, -3.5),
        pos + const Offset(12, -3.5),
        framePaint,
      );

      final badgePaint = Paint()..color = Colors.white;
      final badgePath = Path()
        ..moveTo(pos.dx + 8 - 4, pos.dy + 14)
        ..lineTo(pos.dx + 8, pos.dy + 14 - 3)
        ..lineTo(pos.dx + 8 + 4, pos.dy + 14)
        ..lineTo(pos.dx + 8 + 4, pos.dy + 14 + 3)
        ..quadraticBezierTo(
          pos.dx + 8,
          pos.dy + 14 + 8,
          pos.dx + 8 - 4,
          pos.dy + 14 + 3,
        )
        ..close();
      canvas.drawPath(badgePath, badgePaint);
    }

    if (phase == 'stealing') {
      final qPainter = TextPainter(
        text: const TextSpan(
          text: '?',
          style: TextStyle(
            color: Color(0xFFF59E0B),
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      qPainter.paint(canvas, pos + Offset(-qPainter.width / 2, -35));
    }
  }

  void _drawPCNode(Canvas canvas, Offset pos) {
    final framePaint = Paint()..color = const Color(0xFF1E1E38);
    final borderPaint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final rect = Rect.fromCenter(center: pos, width: 48, height: 36);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      framePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      borderPaint,
    );

    final innerRect = Rect.fromCenter(center: pos, width: 36, height: 24);
    canvas.drawRect(innerRect, Paint()..color = const Color(0xFF161632));

    canvas.drawLine(
      pos + const Offset(0, 18),
      pos + const Offset(0, 28),
      borderPaint,
    );
    canvas.drawLine(
      pos + const Offset(-12, 28),
      pos + const Offset(12, 28),
      borderPaint,
    );

    if (phase == 'blocked_mfa') {
      final phonePaint = Paint()..color = const Color(0xFF1E1E38);
      final phoneRect = Rect.fromCenter(center: pos, width: 24, height: 40);
      canvas.drawRRect(
        RRect.fromRectAndRadius(phoneRect, const Radius.circular(4)),
        phonePaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(phoneRect, const Radius.circular(4)),
        Paint()
          ..color = Colors.grey
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );

      canvas.drawRect(
        Rect.fromCenter(center: pos, width: 16, height: 30),
        Paint()..color = const Color(0xFFEF4444),
      );

      final xPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        pos + const Offset(-4, -4),
        pos + const Offset(4, 4),
        xPaint,
      );
      canvas.drawLine(
        pos + const Offset(4, -4),
        pos + const Offset(-4, 4),
        xPaint,
      );
    }
  }

  void _drawVaultNode(Canvas canvas, Offset pos) {
    final rect = Rect.fromCenter(
      center: pos + const Offset(0, -5),
      width: 60,
      height: 80,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()..color = const Color(0xFF1E1E38),
    );

    final shelfPaint = Paint()
      ..color = const Color(0xFF06B6D4)
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      pos + const Offset(-20, 15),
      pos + const Offset(20, 15),
      shelfPaint,
    );
    canvas.drawLine(
      pos + const Offset(-20, 35),
      pos + const Offset(20, 35),
      shelfPaint,
    );
    canvas.drawLine(
      pos + const Offset(-20, -5),
      pos + const Offset(20, -5),
      shelfPaint,
    );

    final isBreached = phase == 'breached';
    final lockColor = isBreached
        ? const Color(0xFFEF4444)
        : const Color(0xFFF59E0B);
    final lockPaint = Paint()..color = lockColor;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: pos + const Offset(0, 20),
          width: 24,
          height: 18,
        ),
        const Radius.circular(2),
      ),
      lockPaint,
    );
    if (isBreached) {
      final shacklePaint = Paint()
        ..color = lockColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round;
      final path = Path()
        ..moveTo(pos.dx - 8, pos.dy + 11)
        ..lineTo(pos.dx - 8, pos.dy + 5)
        ..arcTo(Rect.fromLTWH(pos.dx - 8, pos.dy - 3, 16, 16), pi, pi, false)
        ..lineTo(pos.dx + 8, pos.dy + 7);
      canvas.drawPath(path, shacklePaint);

      final compPainter = TextPainter(
        text: const TextSpan(
          text: 'COMPROMISED',
          style: TextStyle(
            color: Color(0xFFEF4444),
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      compPainter.paint(canvas, pos + Offset(-compPainter.width / 2, 42));
    } else {
      final shacklePaint = Paint()
        ..color = lockColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;
      canvas.drawArc(
        Rect.fromLTWH(pos.dx - 8, pos.dy + 3, 16, 16),
        pi,
        pi,
        false,
        shacklePaint,
      );

      final keyholePaint = Paint()..color = Colors.white;
      canvas.drawCircle(pos + const Offset(0, 17), 2.0, keyholePaint);
      canvas.drawLine(
        pos + const Offset(0, 19),
        pos + const Offset(0, 24),
        Paint()
          ..color = Colors.white
          ..strokeWidth = 1.5,
      );
    }
  }

  void _drawLurePayload(Canvas canvas, Offset pos, bool isBlocked) {
    final bgPaint = Paint()..color = const Color(0xFFF59E0B);
    canvas.drawCircle(pos, 14.0, bgPaint);

    if (attackType == 'phishing') {
      final envPaint = Paint()
        ..color = const Color(0xFF78350F)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawRect(
        Rect.fromCenter(center: pos, width: 14, height: 8),
        envPaint,
      );
      final path = Path()
        ..moveTo(pos.dx - 7, pos.dy - 4)
        ..lineTo(pos.dx, pos.dy + 1)
        ..lineTo(pos.dx + 7, pos.dy - 4);
      canvas.drawPath(path, envPaint);
    } else {
      final phonePaint = Paint()..color = const Color(0xFF78350F);
      final path = Path()
        ..moveTo(pos.dx - 4, pos.dy - 6)
        ..quadraticBezierTo(pos.dx - 6, pos.dy - 6, pos.dx - 6, pos.dy - 3)
        ..quadraticBezierTo(pos.dx - 6, pos.dy + 1, pos.dx - 4, pos.dy + 3)
        ..quadraticBezierTo(pos.dx + 4, pos.dy + 9, pos.dx + 8, pos.dy + 6)
        ..quadraticBezierTo(pos.dx + 8, pos.dy + 5, pos.dx + 7, pos.dy + 3)
        ..quadraticBezierTo(pos.dx + 5, pos.dy + 1, pos.dx + 3, pos.dy + 2)
        ..quadraticBezierTo(pos.dx + 1, pos.dy + 1, pos.dx - 1, pos.dy - 1)
        ..quadraticBezierTo(pos.dx - 1, pos.dy - 3, pos.dx + 1, pos.dy - 4)
        ..quadraticBezierTo(pos.dx + 1, pos.dy - 6, pos.dx - 1, pos.dy - 7)
        ..close();
      canvas.drawPath(path, phonePaint);
    }

    if (isBlocked) {
      final xPaint = Paint()
        ..color = const Color(0xFFEF4444)
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        pos + const Offset(-10, -10),
        pos + const Offset(10, 10),
        xPaint,
      );
      canvas.drawLine(
        pos + const Offset(10, -10),
        pos + const Offset(-10, 10),
        xPaint,
      );
    }
  }

  void _drawPasswordPayload(Canvas canvas, Offset pos) {
    canvas.drawCircle(pos, 14.0, Paint()..color = const Color(0xFFFCA5A5));
    final keyPaint = Paint()..color = const Color(0xFFEF4444);
    canvas.drawCircle(pos + const Offset(-3, 0), 3.0, keyPaint);
    canvas.drawRect(Rect.fromLTWH(pos.dx, pos.dy - 1, 8, 2), keyPaint);
    canvas.drawRect(Rect.fromLTWH(pos.dx + 3, pos.dy - 1, 1.5, 4), keyPaint);
    canvas.drawRect(Rect.fromLTWH(pos.dx + 6, pos.dy - 1, 1.5, 4), keyPaint);
  }

  void _drawMfaPayload(Canvas canvas, Offset pos) {
    final phonePaint = Paint()..color = const Color(0xFF60A5FA);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: pos, width: 20, height: 28),
        const Radius.circular(3),
      ),
      phonePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: pos, width: 20, height: 28),
        const Radius.circular(3),
      ),
      Paint()
        ..color = const Color(0xFF3D5CFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    canvas.drawCircle(
      pos + const Offset(0, 10),
      2.0,
      Paint()..color = const Color(0xFF3D5CFF),
    );

    final qPainter = TextPainter(
      text: const TextSpan(
        text: '?',
        style: TextStyle(
          color: Color(0xFF3D5CFF),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    qPainter.paint(canvas, pos + Offset(-qPainter.width / 2, -8));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _InsiderThreatPainter extends CustomPainter {
  final String phase;
  final String attackType;
  final bool uebaEnabled;
  final bool dlpEnabled;
  final double animProgress;

  _InsiderThreatPainter({
    required this.phase,
    required this.attackType,
    required this.uebaEnabled,
    required this.dlpEnabled,
    required this.animProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 600.0;
    final scaleY = size.height / 280.0;
    canvas.scale(scaleX, scaleY);

    const dbCenter = Offset(80.0, 150.0);
    const empCenter = Offset(300.0, 150.0);
    const extCenter = Offset(520.0, 150.0);

    const perimeterX = 415.0;

    final linePaintMain = Paint()
      ..color = Colors.grey.withOpacity(0.6)
      ..strokeWidth = 3.0;

    canvas.drawLine(
      dbCenter + const Offset(30, 0),
      empCenter + const Offset(-45, 0),
      linePaintMain,
    );
    _drawDashedLine(
      canvas,
      empCenter + const Offset(55, 0),
      const Offset(perimeterX - 15, 150),
      Colors.grey.withOpacity(0.5),
    );
    _drawDashedLine(
      canvas,
      const Offset(perimeterX + 15, 150),
      extCenter + const Offset(-45, 0),
      Colors.grey.withOpacity(0.5),
    );

    _drawVerticalDashedLine(
      canvas,
      perimeterX,
      50,
      250,
      Colors.grey.withOpacity(dlpEnabled ? 0.0 : 0.5),
    );

    final perimeterText = TextPainter(
      text: const TextSpan(
        text: 'COMPANY PERIMETER',
        style: TextStyle(color: Colors.grey, fontSize: 9),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    perimeterText.paint(
      canvas,
      Offset(perimeterX - perimeterText.width / 2, 35),
    );

    if (dlpEnabled) {
      final shieldPaint = Paint()
        ..color = const Color(0xFF10B981)
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke;
      final auraPaint = Paint()
        ..color = const Color(
          0xFF10B981,
        ).withOpacity(phase == 'blocked_dlp' ? 0.3 : 0.15)
        ..strokeWidth = 16.0
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        const Offset(perimeterX, 50),
        const Offset(perimeterX, 250),
        auraPaint,
      );
      _drawVerticalDashedLine(
        canvas,
        perimeterX,
        50,
        250,
        const Color(0xFF10B981),
      );

      final boxRect = Rect.fromCenter(
        center: const Offset(perimeterX, 150 - 70),
        width: 40,
        height: 20,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(boxRect, const Radius.circular(10)),
        Paint()..color = const Color(0xFF1E1E38),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(boxRect, const Radius.circular(10)),
        shieldPaint,
      );

      final dlpText = TextPainter(
        text: const TextSpan(
          text: 'DLP',
          style: TextStyle(
            color: Color(0xFF10B981),
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      dlpText.paint(canvas, Offset(perimeterX - dlpText.width / 2, 150 - 75));
    }

    _drawDBNode(canvas, dbCenter);
    _drawEmployeeNode(canvas, empCenter);
    _drawDestinationNode(canvas, extCenter);

    final t = animProgress / 100.0;

    if (phase == 'gathering' || phase == 'blocked_ueba') {
      const startX = 80.0 + 30.0 + 14.0;
      const endX = 300.0 - 45.0 - 14.0;
      const blockedX = endX - 20.0;
      final targetEndX = uebaEnabled ? blockedX : endX;
      final x = phase == 'blocked_ueba'
          ? blockedX
          : startX + (targetEndX - startX) * t;

      _drawFolderPayload(
        canvas,
        Offset(x, 150.0),
        const Color(0xFF60A5FA),
        const Color(0xFF2563EB),
        phase == 'blocked_ueba',
      );
    }

    if (phase == 'exfiltrating' ||
        phase == 'blocked_dlp' ||
        phase == 'breached') {
      const startX = 300.0 + 55.0 + 14.0;
      const endX = 520.0;
      const blockedX = perimeterX - 20.0;
      final targetEndX = dlpEnabled ? blockedX : endX;
      final x = phase == 'blocked_dlp'
          ? blockedX
          : (phase == 'breached' ? endX : startX + (targetEndX - startX) * t);

      _drawFolderPayload(
        canvas,
        Offset(x, 150.0),
        const Color(0xFFFCA5A5),
        const Color(0xFFDC2626),
        phase == 'blocked_dlp',
      );
    }
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0;
    const dashWidth = 8.0;
    const dashSpace = 6.0;
    final distance = (p2 - p1).distance;
    final angle = atan2(p2.dy - p1.dy, p2.dx - p1.dx);
    var currentDist = 0.0;
    while (currentDist < distance) {
      final x1 = p1.dx + currentDist * cos(angle);
      final y1 = p1.dy + currentDist * sin(angle);
      currentDist += dashWidth;
      final x2 =
          p1.dx +
          (currentDist < distance ? currentDist : distance) * cos(angle);
      final y2 =
          p1.dy +
          (currentDist < distance ? currentDist : distance) * sin(angle);
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
      currentDist += dashSpace;
    }
  }

  void _drawVerticalDashedLine(
    Canvas canvas,
    double x,
    double y1,
    double y2,
    Color color,
  ) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0;
    const dashHeight = 6.0;
    const dashSpace = 4.0;
    var currentY = y1;
    while (currentY < y2) {
      final nextY = (currentY + dashHeight < y2) ? currentY + dashHeight : y2;
      canvas.drawLine(Offset(x, currentY), Offset(x, nextY), paint);
      currentY = nextY + dashSpace;
    }
  }

  void _drawDBNode(Canvas canvas, Offset center) {
    final rect = Rect.fromCenter(center: center, width: 60, height: 90);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()..color = const Color(0xFF1E1E38),
    );

    for (int i = 0; i < 4; i++) {
      final y = center.dy - 45 + 15 + i * 18;
      final diskRect = Rect.fromLTWH(center.dx - 22, y, 44, 10);
      canvas.drawRRect(
        RRect.fromRectAndRadius(diskRect, const Radius.circular(2)),
        Paint()..color = const Color(0xFF1E40AF),
      );

      final pulsePaint = Paint()
        ..color = phase == 'gathering'
            ? const Color(0xFF10B981)
            : Colors.grey.shade400;
      canvas.drawCircle(Offset(center.dx - 17, y + 5), 2.0, pulsePaint);

      canvas.drawLine(
        Offset(center.dx - 10, y + 5),
        Offset(center.dx + 16, y + 5),
        Paint()
          ..color = const Color(0xFF3B82F6)
          ..strokeWidth = 2.0,
      );
    }

    final dbText = TextPainter(
      text: const TextSpan(
        text: 'DB SERVER',
        style: TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    dbText.paint(canvas, center + Offset(-dbText.width / 2, 48));
  }

  void _drawEmployeeNode(Canvas canvas, Offset center) {
    final isRogue = phase != 'idle' && phase != 'blocked_ueba';
    final userColor = isRogue ? const Color(0xFFEF4444) : Colors.grey.shade400;

    if (uebaEnabled) {
      final scanPaint = Paint()
        ..color = const Color(0xFF10B981).withOpacity(0.6)
        ..strokeWidth = 2.0;
      if (phase != 'blocked_ueba') {
        canvas.drawLine(
          center + const Offset(-60, -18),
          center + const Offset(60, -18),
          scanPaint,
        );
      } else {
        final suspText = TextPainter(
          text: const TextSpan(
            text: 'ACCOUNT SUSPENDED',
            style: TextStyle(
              color: Color(0xFF10B981),
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        suspText.paint(canvas, center + Offset(-suspText.width / 2, -60));
      }
    }

    final avatarCenter = center + const Offset(-30, -18);
    canvas.drawCircle(
      avatarCenter + const Offset(0, -2),
      14.0,
      Paint()..color = userColor,
    );
    final bodyPath = Path()
      ..moveTo(avatarCenter.dx - 22, avatarCenter.dy + 28)
      ..quadraticBezierTo(
        avatarCenter.dx - 22,
        avatarCenter.dy + 3,
        avatarCenter.dx,
        avatarCenter.dy + 3,
      )
      ..quadraticBezierTo(
        avatarCenter.dx + 22,
        avatarCenter.dy + 3,
        avatarCenter.dx + 22,
        avatarCenter.dy + 28,
      )
      ..close();
    canvas.drawPath(bodyPath, Paint()..color = userColor);

    if (isRogue) {
      final maskPaint = Paint()..color = Colors.black;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: avatarCenter + const Offset(0, -5),
            width: 24,
            height: 6,
          ),
          const Radius.circular(1),
        ),
        maskPaint,
      );
      canvas.drawCircle(
        avatarCenter + const Offset(-5, -5),
        1.5,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        avatarCenter + const Offset(5, -5),
        1.5,
        Paint()..color = Colors.white,
      );
    }

    if (phase == 'blocked_ueba') {
      final lockPaint = Paint()..color = const Color(0xFFEF4444);
      final lockCenter = avatarCenter + const Offset(0, 10);
      canvas.drawCircle(
        lockCenter,
        16.0,
        Paint()..color = const Color(0xFF1E1E38),
      );
      canvas.drawCircle(
        lockCenter,
        16.0,
        Paint()
          ..color = const Color(0xFFEF4444)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: lockCenter + const Offset(0, 2),
            width: 12,
            height: 10,
          ),
          const Radius.circular(1),
        ),
        lockPaint,
      );
      canvas.drawArc(
        Rect.fromLTWH(lockCenter.dx - 4, lockCenter.dy - 6, 8, 8),
        pi,
        pi,
        false,
        Paint()
          ..color = const Color(0xFFEF4444)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    }

    final pcPos = center + const Offset(30, -18);
    final pcPaint = Paint()..color = const Color(0xFF1E1E38);
    final borderPaint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 3.0;

    final pcRect = Rect.fromCenter(center: pcPos, width: 48, height: 36);
    canvas.drawRRect(
      RRect.fromRectAndRadius(pcRect, const Radius.circular(4)),
      pcPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(pcRect, const Radius.circular(4)),
      borderPaint..style = PaintingStyle.stroke,
    );

    canvas.drawRect(
      Rect.fromCenter(center: pcPos, width: 36, height: 24),
      Paint()
        ..color = phase == 'blocked_ueba'
            ? const Color(0xFFEF4444)
            : const Color(0xFF161632),
    );
    canvas.drawLine(
      pcPos + const Offset(0, 18),
      pcPos + const Offset(0, 28),
      borderPaint,
    );
    canvas.drawLine(
      pcPos + const Offset(-12, 28),
      pcPos + const Offset(12, 28),
      borderPaint,
    );

    if (phase == 'blocked_ueba') {
      final exclamation = TextPainter(
        text: const TextSpan(
          text: '!',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      exclamation.paint(
        canvas,
        pcPos - Offset(exclamation.width / 2, exclamation.height / 2),
      );
    }

    final labelText = isRogue ? 'ROGUE INSIDER' : 'EMPLOYEE';
    final labelColor = isRogue ? const Color(0xFFEF4444) : Colors.white;
    final textPainter = TextPainter(
      text: TextSpan(
        text: labelText,
        style: TextStyle(
          color: labelColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, center + Offset(-textPainter.width / 2, 35));
  }

  void _drawDestinationNode(Canvas canvas, Offset center) {
    final bgPaint = Paint()..color = const Color(0xFF1E1E38);
    final borderPaint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 2.0;

    final cardRect = Rect.fromCenter(
      center: center + const Offset(0, -3),
      width: 90,
      height: 65,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(cardRect, const Radius.circular(6)),
      bgPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(cardRect, const Radius.circular(6)),
      borderPaint..style = PaintingStyle.stroke,
    );

    final cardLabel = attackType == 'usb' ? 'USB DRIVE' : 'PERSONAL CLOUD';
    final textPainter = TextPainter(
      text: TextSpan(
        text: cardLabel,
        style: TextStyle(
          color: Colors.grey.shade400,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, center + Offset(-textPainter.width / 2, 32));

    if (attackType == 'usb') {
      final usbPaint = Paint()..color = Colors.grey;
      canvas.drawRect(
        Rect.fromLTWH(center.dx - 10, center.dy - 22, 14, 12),
        usbPaint,
      );
      canvas.drawRect(
        Rect.fromLTWH(center.dx - 15, center.dy - 10, 20, 24),
        usbPaint,
      );
      canvas.drawCircle(
        center + const Offset(-5, 2),
        4.0,
        Paint()..color = const Color(0xFF1E1E38),
      );
    } else {
      final cloudPaint = Paint()..color = const Color(0xFF06B6D4);
      final path = Path()
        ..moveTo(center.dx - 15, center.dy)
        ..cubicTo(
          center.dx - 20,
          center.dy,
          center.dx - 20,
          center.dy - 7,
          center.dx - 15,
          center.dy - 7,
        )
        ..cubicTo(
          center.dx - 15,
          center.dy - 15,
          center.dx - 5,
          center.dy - 17,
          center.dx - 2,
          center.dy - 13,
        )
        ..cubicTo(
          center.dx + 2,
          center.dy - 20,
          center.dx + 15,
          center.dy - 17,
          center.dx + 15,
          center.dy - 7,
        )
        ..cubicTo(
          center.dx + 22,
          center.dy - 7,
          center.dx + 22,
          center.dy,
          center.dx + 15,
          center.dy,
        )
        ..close();
      canvas.drawPath(path, cloudPaint);
    }

    if (phase == 'breached') {
      final breachText = TextPainter(
        text: const TextSpan(
          text: 'COMPROMISED',
          style: TextStyle(
            color: Color(0xFFEF4444),
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      breachText.paint(canvas, center + Offset(-breachText.width / 2, 45));
    }
  }

  void _drawFolderPayload(
    Canvas canvas,
    Offset pos,
    Color fill,
    Color stroke,
    bool isBlocked,
  ) {
    final folderPaint = Paint()..color = fill;
    final strokePaint = Paint()
      ..color = stroke
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(pos.dx - 16, pos.dy - 8)
      ..lineTo(pos.dx - 4, pos.dy - 8)
      ..lineTo(pos.dx, pos.dy - 4)
      ..lineTo(pos.dx + 16, pos.dy - 4)
      ..quadraticBezierTo(pos.dx + 18, pos.dy - 4, pos.dx + 18, pos.dy - 2)
      ..lineTo(pos.dx + 18, pos.dy + 10)
      ..quadraticBezierTo(pos.dx + 18, pos.dy + 12, pos.dx + 16, pos.dy + 12)
      ..lineTo(pos.dx - 16, pos.dy + 12)
      ..quadraticBezierTo(pos.dx - 18, pos.dy + 12, pos.dx - 18, pos.dy + 10)
      ..lineTo(pos.dx - 18, pos.dy - 6)
      ..quadraticBezierTo(pos.dx - 18, pos.dy - 8, pos.dx - 16, pos.dy - 8)
      ..close();

    canvas.drawPath(path, folderPaint);
    canvas.drawPath(path, strokePaint);

    if (stroke == const Color(0xFFDC2626)) {
      final secretText = TextPainter(
        text: const TextSpan(
          text: 'SECRET',
          style: TextStyle(
            color: Color(0xFF991B1B),
            fontSize: 6,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      secretText.paint(canvas, pos - Offset(secretText.width / 2, -1));
    }

    if (isBlocked) {
      final xPaint = Paint()
        ..color = const Color(0xFFEF4444)
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        pos + const Offset(-10, -10),
        pos + const Offset(10, 10),
        xPaint,
      );
      canvas.drawLine(
        pos + const Offset(10, -10),
        pos + const Offset(-10, 10),
        xPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
