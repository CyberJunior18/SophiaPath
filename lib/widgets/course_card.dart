import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/course/course_info.dart';

class CourseCard extends StatelessWidget {
  final CourseInfo? course;
  final String? title;
  final String? assetImagePath;
  final bool isRegistered;
  final double progress;
  final int lessonsFinished;
  final int totalLessons;
  final bool isComingSoon;
  final VoidCallback? onTap;
  final IconData fallbackIcon;

  const CourseCard({
    super.key,
    this.course,
    this.title,
    this.assetImagePath,
    required this.isRegistered,
    this.progress = 0.0,
    this.lessonsFinished = 0,
    this.totalLessons = 0,
    this.isComingSoon = false,
    this.onTap,
    required this.fallbackIcon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayTitle = course?.title ?? title ?? 'Course';
    final hasNetworkImage =
        course?.imageUrl != null && course!.imageUrl.isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.primaryColor.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image Section
            Padding(
              padding: const EdgeInsets.only(
                left: 5,
                right: 5,
                top: 5,
                bottom: 35,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: assetImagePath != null
                    ? Image.asset(
                        assetImagePath!,
                        fit: BoxFit.contain,
                        alignment: Alignment.center,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildFallbackIcon(theme),
                      )
                    : (hasNetworkImage
                          ? Image.network(
                              course!.imageUrl,
                              fit: BoxFit.contain,
                              alignment: Alignment.center,
                              errorBuilder: (context, error, stackTrace) =>
                                  _buildFallbackIcon(theme),
                            )
                          : _buildFallbackIcon(theme)),
              ),
            ),

            // Content Section at the bottom in an opacity container
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(
                        alpha: 0.3,
                      ), // Lighter to see the blur
                      border: Border(
                        top: BorderSide(
                          color: theme.primaryColor.withValues(alpha: 0.6),
                          width: 1.5,
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 10.0,
                      horizontal: 16.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Title
                        Text(
                          displayTitle,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // Progress Section
                        if (isRegistered && !isComingSoon) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    backgroundColor: Colors.white.withValues(
                                      alpha: 0.2,
                                    ),
                                    color: theme.primaryColor,
                                    minHeight: 8,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                '${(progress * 100).toInt()}%',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: theme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackIcon(ThemeData theme) {
    return Center(
      child: Icon(fallbackIcon, size: 40, color: theme.primaryColor),
    );
  }
}
