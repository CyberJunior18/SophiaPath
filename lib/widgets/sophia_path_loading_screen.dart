import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/settings_provider.dart';

const List<String> learningQuotes = [
  "The capacity to learn is a gift; the ability to learn is a skill; the willingness to learn is a choice. — Brian Herbert",
  "Live as if you were to die tomorrow. Learn as if you were to live forever. — Mahatma Gandhi",
  "Intellectual growth should commence at birth and cease only at death. — Albert Einstein",
  "The beautiful thing about learning is that nobody can take it away from you. — B.B. King",
  "Do not fear failure. Fear being in the exact same place next year as you are today.",
  "Wisdom is not a product of schooling but of the lifelong attempt to acquire it. — Albert Einstein",
  "Continuous improvement is better than delayed perfection. — Mark Twain",
  "The only true wisdom is in knowing you know nothing. — Socrates",
  "Be not afraid of going slowly, be afraid only of standing still. — Chinese Proverb",
  "Education is the passport to the future, for tomorrow belongs to those who prepare for it today. — Malcolm X",
  "Success is not final, failure is not fatal: it is the courage to continue that counts. — Winston Churchill",
  "The mind is not a vessel to be filled, but a fire to be kindled. — Plutarch",
  "Learning is the only thing the mind never exhausts, never fears, and never regrets. — Leonardo da Vinci",
  "Develop a passion for learning. If you do, you will never cease to grow. — Anthony J. D'Angelo",
  "All life is an experiment. The more experiments you make the better. — Ralph Waldo Emerson",
  "Growth begins at the end of your comfort zone. Stretch your boundaries.",
  "The more that you read, the more things you will know. The more that you learn, the more places you'll go. — Dr. Seuss",
  "Every master was once a beginner. Keep pushing forward.",
  "In a world of constant change, the learners inherit the earth.",
  "Small daily improvements over time lead to stunning results. Focus on 1% better every day.",
];

class SophiaPathLogo extends StatelessWidget {
  final double size;
  const SophiaPathLogo({super.key, this.size = 140});

  Color _darken(Color color, [double amount = 0.18]) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final secondaryColor = _darken(primaryColor, 0.15);
    final logoGradient = settings.logoGradient;

    final gradient = logoGradient
        ? LinearGradient(
            colors: [primaryColor, secondaryColor],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          )
        : LinearGradient(
            colors: [
              primaryColor,
              primaryColor,
              secondaryColor,
              secondaryColor,
            ],
            stops: const [0.0, 0.5, 0.5, 1.0],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          );

    return ShaderMask(
      shaderCallback: (bounds) => gradient.createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: Image.asset(
        'assets/sp-logo.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }
}

class ThreeDotsLoadingIndicator extends StatefulWidget {
  final Color color;
  const ThreeDotsLoadingIndicator({super.key, required this.color});

  @override
  State<ThreeDotsLoadingIndicator> createState() =>
      _ThreeDotsLoadingIndicatorState();
}

class _ThreeDotsLoadingIndicatorState extends State<ThreeDotsLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.35;
            final t = _controller.value;
            final angle = (t * 2 * pi) - (delay * pi);
            final scale = 1.0 + 0.28 * sin(angle);
            final opacity = (0.6 + 0.4 * sin(angle)).clamp(0.2, 1.0);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: widget.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class SophiaPathLoadingScreen extends StatefulWidget {
  final String? appBarTitle;
  const SophiaPathLoadingScreen({super.key, this.appBarTitle});

  @override
  State<SophiaPathLoadingScreen> createState() =>
      _SophiaPathLoadingScreenState();
}

class _SophiaPathLoadingScreenState extends State<SophiaPathLoadingScreen>
    with SingleTickerProviderStateMixin {
  late final String _quote;
  late AnimationController _entryController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    final random = Random();
    _quote = learningQuotes[random.nextInt(learningQuotes.length)];

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _scaleAnimation = Tween<double>(begin: 0.94, end: 1.015).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Cubic(0.1, 0.8, 0.2, 1.0),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  Color _darken(Color color, [double amount = 0.18]) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final secondaryColor = _darken(primaryColor, 0.15);

    final content = AnimatedBuilder(
      animation: _entryController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SophiaPathLogo(size: 100),
                    const SizedBox(height: 24),
                    ShaderMask(
                      shaderCallback: (bounds) {
                        return LinearGradient(
                          colors: [primaryColor, secondaryColor],
                          stops: const [0.59, 0.59],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ).createShader(bounds);
                      },
                      blendMode: BlendMode.srcIn,
                      child: Text(
                        'SophiaPath',
                        style: GoogleFonts.outfit(
                          fontSize: 38,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Container(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: Text(
                        _quote,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 14.5,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    ThreeDotsLoadingIndicator(color: primaryColor),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (widget.appBarTitle != null) {
      return Scaffold(body: content);
    }

    return Scaffold(body: content);
  }
}
