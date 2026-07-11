import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_provider.dart';

class BackgroundAnimationWidget extends StatefulWidget {
  final Widget child;
  const BackgroundAnimationWidget({super.key, required this.child});

  @override
  State<BackgroundAnimationWidget> createState() => _BackgroundAnimationWidgetState();
}

class _BackgroundAnimationWidgetState extends State<BackgroundAnimationWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    
    if (!settings.globalBg) {
      return widget.child;
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Stack(
      children: [
        // Animation backdrop
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: BackdropPainter(
                  style: settings.bgStyle,
                  progress: _controller.value,
                  primaryColor: theme.primaryColor,
                  textColor: theme.colorScheme.onSurface,
                  isDark: isDark,
                ),
              );
            },
          ),
        ),
        // Transparent/glassmorphism tint overlay for text readability
        Positioned.fill(
          child: Container(
            color: theme.scaffoldBackgroundColor.withValues(alpha: 0.88),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class BackdropPainter extends CustomPainter {
  final String style;
  final double progress;
  final Color primaryColor;
  final Color textColor;
  final bool isDark;

  BackdropPainter({
    required this.style,
    required this.progress,
    required this.primaryColor,
    required this.textColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke;

    switch (style) {
      case 'circuit':
        _paintCircuit(canvas, size, paint);
        break;
      case 'aurora':
        _paintAurora(canvas, size, paint);
        break;
      case 'grid':
        _paintGrid(canvas, size, paint);
        break;
      case 'matrix':
        _paintMatrix(canvas, size, paint);
        break;
      case 'vortex':
        _paintVortex(canvas, size, paint);
        break;
      case 'warp':
        _paintWarp(canvas, size, paint);
        break;
      case 'constellation':
      default:
        _paintConstellation(canvas, size, paint);
        break;
    }
  }

  void _paintConstellation(Canvas canvas, Size size, Paint paint) {
    final int count = 28;
    final List<Offset> points = [];

    // Procedurally calculate smooth orbital points
    for (int i = 0; i < count; i++) {
      final double angleOffset = i * (math.pi * 2 / count);
      final double phase = progress * math.pi * 2;
      
      final double rx = size.width * (0.15 + 0.3 * math.sin(i * 15.3));
      final double ry = size.height * (0.15 + 0.3 * math.cos(i * 24.7));
      final double cx = size.width * (0.35 + 0.3 * math.cos(i * 4.9));
      final double cy = size.height * (0.35 + 0.3 * math.sin(i * 12.1));

      final double x = cx + rx * math.sin(phase + angleOffset);
      final double y = cy + ry * math.cos(phase + angleOffset * 1.5);
      points.add(Offset(x, y));
    }

    // Draw connection lines
    for (int i = 0; i < count; i++) {
      for (int j = i + 1; j < count; j++) {
        final double dist = (points[i] - points[j]).distance;
        final double maxDist = 130.0;
        if (dist < maxDist) {
          final double opacity = (1.0 - (dist / maxDist)) * 0.22;
          paint.color = primaryColor.withValues(alpha: opacity);
          paint.strokeWidth = 0.8;
          canvas.drawLine(points[i], points[j], paint);
        }
      }
    }

    // Draw nodes
    paint.style = PaintingStyle.fill;
    for (int i = 0; i < count; i++) {
      paint.color = primaryColor.withValues(alpha: 0.35);
      canvas.drawCircle(points[i], 3.5, paint);
      paint.color = primaryColor.withValues(alpha: 0.7);
      canvas.drawCircle(points[i], 1.5, paint);
    }
  }

  void _paintCircuit(Canvas canvas, Size size, Paint paint) {
    paint.color = primaryColor.withValues(alpha: 0.12);
    paint.strokeWidth = 1.2;

    final int rows = 12;
    final int cols = 8;
    final double stepY = size.height / (rows + 1);
    final double stepX = size.width / (cols + 1);

    for (int r = 1; r <= rows; r++) {
      final double y = r * stepY;
      // Draw horizontal trace
      final double startX = stepX;
      final double endX = size.width - stepX;
      final double currentX = startX + (endX - startX) * ((progress + (r * 0.08)) % 1.0);
      
      canvas.drawLine(Offset(startX, y), Offset(currentX, y), paint);

      // Draw branch diagonals at intervals
      if (r % 3 == 0) {
        canvas.drawLine(Offset(currentX, y), Offset(currentX + 30, y + 30), paint);
        paint.style = PaintingStyle.fill;
        paint.color = primaryColor.withValues(alpha: 0.25);
        canvas.drawCircle(Offset(currentX, y), 3, paint);
        canvas.drawCircle(Offset(currentX + 30, y + 30), 2, paint);
        paint.style = PaintingStyle.stroke;
        paint.color = primaryColor.withValues(alpha: 0.12);
      }
    }
  }

  void _paintAurora(Canvas canvas, Size size, Paint paint) {
    paint.style = PaintingStyle.fill;
    final int waves = 3;

    for (int w = 0; w < waves; w++) {
      final double wavePhase = progress * math.pi * 2 + (w * math.pi / 2);
      final double amplitude = 40.0 + (w * 15.0);
      final double frequency = 0.006 - (w * 0.001);
      final double baseHeight = size.height * (0.6 + w * 0.08);

      final path = Path();
      path.moveTo(0, size.height);
      for (double x = 0; x <= size.width; x += 15) {
        final double y = baseHeight + math.sin(x * frequency + wavePhase) * amplitude;
        path.lineTo(x, y);
      }
      path.lineTo(size.width, size.height);
      path.close();

      paint.color = primaryColor.withValues(alpha: 0.06 - (w * 0.015));
      canvas.drawPath(path, paint);
    }
  }

  void _paintGrid(Canvas canvas, Size size, Paint paint) {
    paint.color = primaryColor.withValues(alpha: 0.08);
    paint.strokeWidth = 1.0;

    final double horizon = size.height * 0.3;
    final double center = size.width / 2;

    // Vanishing perspective lines
    final int perspectiveLines = 16;
    for (int i = 0; i <= perspectiveLines; i++) {
      final double ratio = i / perspectiveLines;
      final double endX = size.width * ratio;
      canvas.drawLine(Offset(center, horizon), Offset(endX, size.height), paint);
    }

    // Scrolling horizontal grid lines
    final int horizLines = 10;
    for (int i = 0; i < horizLines; i++) {
      final double p = ((i / horizLines) + progress) % 1.0;
      // Exponential spacing to simulate perspective depth
      final double y = horizon + (size.height - horizon) * math.pow(p, 2);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _paintMatrix(Canvas canvas, Size size, Paint paint) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final int streams = 14;
    final double spacing = size.width / streams;

    for (int i = 0; i < streams; i++) {
      final double x = (i * spacing) + (spacing / 2);
      final double speedFactor = 0.3 + (i % 5) * 0.15;
      final double startY = (progress * size.height * speedFactor) % size.height;

      // Draw a vertical column of characters
      final int len = 10;
      for (int charIndex = 0; charIndex < len; charIndex++) {
        final double y = startY - (charIndex * 18);
        if (y < 0 || y > size.height) continue;

        // Character selection based on index
        final String code = String.fromCharCode(48 + ((i + charIndex + (progress * 100).toInt()) % 10));
        final double opacity = (1.0 - (charIndex / len)) * 0.18;

        textPainter.text = TextSpan(
          text: code,
          style: TextStyle(
            color: (charIndex == 0)
                ? Colors.white.withValues(alpha: 0.35)
                : primaryColor.withValues(alpha: opacity),
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(x - textPainter.width / 2, y));
      }
    }
  }

  void _paintVortex(Canvas canvas, Size size, Paint paint) {
    paint.style = PaintingStyle.fill;
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final int starsCount = 45;

    for (int i = 0; i < starsCount; i++) {
      final double orbitRadius = 40.0 + (i * 8.0);
      final double angle = (progress * math.pi * 2 * (1.5 - (orbitRadius / size.width))) + (i * 12.3);
      
      final double x = cx + orbitRadius * math.cos(angle);
      final double y = cy + orbitRadius * math.sin(angle) * (size.height / size.width); // Adjust ratio

      final double sizeFactor = 1.0 + (i % 3);
      final double opacity = 0.08 + 0.12 * math.sin(angle);
      
      paint.color = primaryColor.withValues(alpha: opacity);
      canvas.drawCircle(Offset(x, y), sizeFactor, paint);
    }
  }

  void _paintWarp(Canvas canvas, Size size, Paint paint) {
    paint.style = PaintingStyle.fill;
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final int starCount = 50;

    for (int i = 0; i < starCount; i++) {
      final double seed = i * 23.45;
      final double angle = seed % (math.pi * 2);
      
      // Moving radial progress
      final double speed = 0.2 + (i % 4) * 0.2;
      final double starProgress = ((progress * speed) + (i / starCount)) % 1.0;

      final double maxRadius = math.max(size.width, size.height) * 0.7;
      final double radius = starProgress * maxRadius;

      final double x = cx + radius * math.cos(angle);
      final double y = cy + radius * math.sin(angle);

      // Tail length proportional to velocity/progress
      final double tailX = cx + (radius - (starProgress * 20)) * math.cos(angle);
      final double tailY = cy + (radius - (starProgress * 20)) * math.sin(angle);

      final double opacity = starProgress * 0.25;
      paint.color = primaryColor.withValues(alpha: opacity);
      paint.strokeWidth = 1.0 + starProgress * 2.0;

      canvas.drawLine(Offset(tailX, tailY), Offset(x, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant BackdropPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.style != style || oldDelegate.primaryColor != primaryColor;
  }
}
