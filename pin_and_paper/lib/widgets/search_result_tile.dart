import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/search_result.dart';

class SearchResultTile extends StatelessWidget {
  final SearchResult result;
  final String query;
  final VoidCallback onTap;
  final String? breadcrumb;  // v4 CRITICAL #1: Pre-loaded breadcrumb

  const SearchResultTile({
    super.key,
    required this.result,
    required this.query,
    required this.onTap,
    this.breadcrumb,  // v4: Passed from parent, no async fetch!
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        result.task.completed
            ? Icons.check_circle
            : Icons.radio_button_unchecked,
      ),
      title: _buildHighlightedText(
        context: context,
        text: result.task.title,
        matches: result.matches.titleMatches,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // v4 CRITICAL #1: Pre-loaded breadcrumb, no FutureBuilder!
          if (breadcrumb != null && breadcrumb!.isNotEmpty) ...[
            Text(
              breadcrumb!,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 4),
          ],
          // v3 NEW: Show match in notes if present
          // TODO: Uncomment when Task.notes field is added
          // if (result.matches.notesMatches.isNotEmpty && result.task.notes != null) ...[
          //   Text(
          //     'Notes: ${_truncateNotes(result.task.notes!)}',
          //     style: TextStyle(fontSize: 12),
          //     maxLines: 1,
          //     overflow: TextOverflow.ellipsis,
          //   ),
          // ],
        ],
      ),
      // FIX (Codex): Gate debug score display with kDebugMode
      trailing: kDebugMode
          ? Text(
              'Score: ${(result.score * 100).toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            )
          : null,
      onTap: onTap,
    );
  }

  String _truncateNotes(String notes) {
    const maxLength = 60;
    if (notes.length <= maxLength) return notes;
    return '${notes.substring(0, maxLength)}...';
  }

  // v3 FIX (Codex): Implement match highlighting using MatchRange
  Widget _buildHighlightedText({
    required BuildContext context,
    required String text,
    required List<MatchRange> matches,
  }) {
    if (matches.isEmpty) {
      return Text(text);
    }

    // Build list of text spans with highlights
    final spans = <TextSpan>[];
    int currentIndex = 0;

    // Sort matches by start position to ensure proper rendering
    final sortedMatches = List<MatchRange>.from(matches)
      ..sort((a, b) => a.start.compareTo(b.start));

    for (final match in sortedMatches) {
      // Add text before match (if any)
      if (match.start > currentIndex) {
        spans.add(TextSpan(
          text: text.substring(currentIndex, match.start),
        ));
      }

      // Add highlighted match
      spans.add(TextSpan(
        text: text.substring(match.start, match.end),
        style: TextStyle(
          backgroundColor: Colors.yellow.withValues(alpha: 0.3),
          fontWeight: FontWeight.bold,
        ),
      ));

      currentIndex = match.end;
    }

    // Add remaining text after last match
    if (currentIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(currentIndex),
      ));
    }

    return RichText(
      text: TextSpan(
        style: DefaultTextStyle.of(context).style,
        children: spans,
      ),
    );
  }
}
