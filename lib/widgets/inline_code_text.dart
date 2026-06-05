import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class InlineCodeText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const InlineCodeText(this.text, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final normalizedText = text.replaceAll(r'\n', '\n');
    final baseStyle =
        style ??
        GoogleFonts.poppins(fontSize: 14, color: theme.colorScheme.onSurface);

    final spans = <InlineSpan>[];
    final pattern = RegExp(r'<code>(.*?)</code>', dotAll: true);
    var lastEnd = 0;

    for (final match in pattern.allMatches(normalizedText)) {
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: normalizedText.substring(lastEnd, match.start),
            style: baseStyle,
          ),
        );
      }

      final code = match.group(1) ?? '';

      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              // border: Border.all(
              //   color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
              // ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  code,
                  style: GoogleFonts.robotoMono(
                    fontSize: (baseStyle.fontSize ?? 14) - 1,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
                SizedBox(height: 4),
              ],
            ),
          ),
        ),
      );

      lastEnd = match.end;
    }

    if (lastEnd < normalizedText.length) {
      spans.add(
        TextSpan(text: normalizedText.substring(lastEnd), style: baseStyle),
      );
    }

    return RichText(text: TextSpan(children: spans));
  }
}
