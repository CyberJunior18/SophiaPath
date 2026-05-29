import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class InlineCodeText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const InlineCodeText(this.text, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle =
        style ??
        GoogleFonts.poppins(fontSize: 14, color: theme.colorScheme.onSurface);

    final spans = <InlineSpan>[];
    final pattern = RegExp(r'<code>(.*?)<\\/code>', dotAll: false);
    var lastEnd = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastEnd, match.start),
            style: baseStyle,
          ),
        );
      }

      final code = match.group(1) ?? '';

      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark
                  ? const Color(0xFF1E1E1E)
                  : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              code,
              style: GoogleFonts.robotoMono(
                fontSize: (baseStyle.fontSize ?? 14) - 1,
                color: theme.brightness == Brightness.dark
                    ? const Color(0xFF9CDCFE)
                    : const Color(0xFF0451A5),
              ),
            ),
          ),
        ),
      );

      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: baseStyle));
    }

    return RichText(text: TextSpan(children: spans));
  }
}
