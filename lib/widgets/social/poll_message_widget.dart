import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Widget that renders a poll inside a message bubble.
/// Shows options with vote counts, progress bars, and handles voting.
class PollMessageWidget extends StatelessWidget {
  final String question;
  final List<dynamic> options;
  final List<dynamic>? votes; // Each entry maps optionIndex → list of voter IDs
  final String? currentUserId;
  final void Function(int optionIndex)? onVote;

  const PollMessageWidget({
    super.key,
    required this.question,
    required this.options,
    this.votes,
    this.currentUserId,
    this.onVote,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalVotes = _getTotalVotes();
    final userVotedIndex = _getUserVotedIndex();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.poll, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                'Poll',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            question,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(options.length, (index) {
            final optionText = options[index]?.toString() ?? 'Option ${index + 1}';
            final optionVoteCount = _getOptionVoteCount(index);
            final percentage = totalVotes > 0 ? optionVoteCount / totalVotes : 0.0;
            final isSelected = userVotedIndex == index;

            return GestureDetector(
              onTap: onVote != null && userVotedIndex == null
                  ? () => onVote!(index)
                  : null,
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outlineVariant.withOpacity(0.5),
                    width: isSelected ? 2 : 1,
                  ),
                  color: isSelected
                      ? theme.colorScheme.primary.withOpacity(0.08)
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            optionText,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (totalVotes > 0)
                          Text(
                            '${(percentage * 100).toInt()}%',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                    if (totalVotes > 0) ...[
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: percentage,
                          minHeight: 4,
                          backgroundColor: theme.colorScheme.outlineVariant.withOpacity(0.2),
                          valueColor: AlwaysStoppedAnimation(
                            isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.primary.withOpacity(0.5),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 4),
          Text(
            '$totalVotes vote${totalVotes == 1 ? '' : 's'}',
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  int _getTotalVotes() {
    if (votes == null || votes!.isEmpty) return 0;
    int count = 0;
    for (final v in votes!) {
      if (v is List) {
        count += v.length;
      } else if (v is Map) {
        // If votes is stored as { optionIndex: [userIds] }
        for (final entry in v.values) {
          if (entry is List) count += entry.length;
        }
      }
    }
    return count;
  }

  int _getOptionVoteCount(int index) {
    if (votes == null || votes!.isEmpty) return 0;
    if (index < votes!.length && votes![index] is List) {
      return (votes![index] as List).length;
    }
    return 0;
  }

  int? _getUserVotedIndex() {
    if (votes == null || currentUserId == null) return null;
    final uid = int.tryParse(currentUserId!) ?? currentUserId;
    for (int i = 0; i < votes!.length; i++) {
      if (votes![i] is List) {
        final voterList = votes![i] as List;
        if (voterList.any((v) => v.toString() == uid.toString())) {
          return i;
        }
      }
    }
    return null;
  }
}
