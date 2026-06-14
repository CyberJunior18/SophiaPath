import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class UmlDiagramWidget extends StatelessWidget {
  final Map<String, dynamic> data;

  /// If true, no outer border/shadow wrapper is added (used when rendering
  /// multiple diagrams inside a parent container).
  final bool compact;

  const UmlDiagramWidget({super.key, required this.data, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final title = (data['title'] ?? '').toString();
    final isAbstract = data['abstract'] == true;
    final rawAttributes = data['attributes'];
    final rawMethods = data['methods'];

    final attributes = rawAttributes is List
        ? rawAttributes
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList()
        : <Map<String, dynamic>>[];

    final methods = rawMethods is List
        ? rawMethods
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList()
        : <Map<String, dynamic>>[];

    final diagramBody = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // === CLASS NAME SECTION ===
        _buildSection(
          context: context,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                if (isAbstract)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '«abstract»',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    fontStyle: isAbstract ? FontStyle.italic : FontStyle.normal,
                    color: isAbstract
                        ? colorScheme.primary
                        : colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          showBottomBorder: true,
          isTitle: true,
          isAbstract: isAbstract,
        ),

        // === ATTRIBUTES SECTION ===
        if (attributes.isNotEmpty)
          _buildSection(
            context: context,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int i = 0; i < attributes.length; i++) ...[
                    if (i > 0) const SizedBox(height: 4),
                    _buildAttributeLine(context, attributes[i]),
                  ],
                ],
              ),
            ),
            showBottomBorder: methods.isNotEmpty,
            isTitle: false,
          ),

        // === METHODS SECTION ===
        if (methods.isNotEmpty)
          _buildSection(
            context: context,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int i = 0; i < methods.length; i++) ...[
                    if (i > 0) const SizedBox(height: 4),
                    _buildMethodLine(context, methods[i]),
                  ],
                ],
              ),
            ),
            showBottomBorder: false,
            isTitle: false,
          ),
      ],
    );

    if (compact) return diagramBody;

    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.maxWidth.clamp(240.0, 500.0);

        return Center(
          child: Container(
            width: boxWidth,
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.5),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: diagramBody,
          ),
        );
      },
    );
  }

  Widget _buildSection({
    required BuildContext context,
    required Widget child,
    required bool showBottomBorder,
    required bool isTitle,
    bool isAbstract = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: isTitle
            ? (isAbstract
                  ? colorScheme.primary.withValues(alpha: 0.12)
                  : colorScheme.primary.withValues(alpha: 0.08))
            : Colors.transparent,
        border: showBottomBorder
            ? Border(
                bottom: BorderSide(
                  color: colorScheme.primary.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              )
            : null,
      ),
      child: child,
    );
  }

  Widget _buildAttributeLine(BuildContext context, Map<String, dynamic> attr) {
    final name = (attr['name'] ?? '').toString();
    final type = (attr['type'] ?? '').toString();
    final visibility = (attr['visibility'] ?? '').toString().toLowerCase();

    String visibilitySymbol;
    switch (visibility) {
      case 'public':
        visibilitySymbol = '+';
        break;
      case 'protected':
        visibilitySymbol = '#';
        break;
      case 'private':
      default:
        visibilitySymbol = '-';
        break;
    }

    // Underline static attributes
    final isStatic = attr['static'] == true;

    return _buildLine(
      context,
      '$visibilitySymbol $name : $type',
      italic: false,
      underline: isStatic,
    );
  }

  Widget _buildMethodLine(BuildContext context, Map<String, dynamic> method) {
    final name = (method['name'] ?? '').toString();
    final methodType = (method['returnType'] ?? '').toString();
    final rawParams = method['parameters'];

    final params = rawParams is List
        ? rawParams
              .whereType<Map>()
              .map((p) => Map<String, dynamic>.from(p))
              .toList()
        : <Map<String, dynamic>>[];

    // Build parameter string like "int year, String month, int day"
    final paramStrings = params.map((p) {
      final pType = (p['type'] ?? '').toString();
      final pName = (p['name'] ?? '').toString();
      if (pType.isNotEmpty && pName.isNotEmpty) {
        return '$pType $pName';
      }
      return pName.isNotEmpty ? pName : pType;
    }).toList();

    final paramStr = paramStrings.join(', ');

    String visibilitySymbol;
    String returnTypeStr;

    if (methodType == 'constructor') {
      visibilitySymbol = '+';
      returnTypeStr = '';
    } else {
      visibilitySymbol = '+';
      returnTypeStr = ' : $methodType';
    }

    final lineText = '$visibilitySymbol $name($paramStr)$returnTypeStr';
    final isAbstractMethod = method['abstract'] == true;
    final isStaticMethod = method['static'] == true;

    return _buildLine(
      context,
      lineText,
      italic: isAbstractMethod,
      underline: isStaticMethod,
    );
  }

  Widget _buildLine(
    BuildContext context,
    String text, {
    bool italic = false,
    bool underline = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Text(
      text,
      style: GoogleFonts.robotoMono(
        fontSize: 13,
        height: 1.4,
        color: colorScheme.onSurface,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        decoration: underline ? TextDecoration.underline : TextDecoration.none,
      ),
    );
  }
}
