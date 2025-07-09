import 'package:flutter/material.dart';

class TaggedContent extends StatelessWidget {
  final String content;
  final TextStyle? textStyle;
  final TextStyle? tagStyle;

  const TaggedContent({
    Key? key,
    required this.content,
    this.textStyle,
    this.tagStyle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Default text style
    final defaultTextStyle = textStyle ??
        Theme.of(context).textTheme.bodyMedium ??
        const TextStyle(fontSize: 14);

    // Style for tagged names (blue and bold)
    final defaultTagStyle = tagStyle ??
        defaultTextStyle.copyWith(
          color: Colors.blue,
          fontWeight: FontWeight.bold,
        );

    // Regular expression to find tagged users
    final pattern = RegExp(r'<tagged>(.*?)</tagged>');

    List<TextSpan> textSpans = [];
    int lastMatchEnd = 0;

    // Find all tagged names in the content
    for (final match in pattern.allMatches(content)) {
      final taggedName = match.group(1)!; // Just the name between the tags
      final matchStart = match.start;
      final matchEnd = match.end;

      // Add text before this match
      if (matchStart > lastMatchEnd) {
        textSpans.add(
          TextSpan(
            text: content.substring(lastMatchEnd, matchStart),
            style: defaultTextStyle,
          ),
        );
      }

      // Add the tagged name with special styling
      textSpans.add(
        TextSpan(
          text: taggedName,
          style: defaultTagStyle,
        ),
      );

      lastMatchEnd = matchEnd;
    }

    // Add any remaining text after the last match
    if (lastMatchEnd < content.length) {
      textSpans.add(
        TextSpan(
          text: content.substring(lastMatchEnd),
          style: defaultTextStyle,
        ),
      );
    }

    return RichText(
      text: TextSpan(
        style: defaultTextStyle,
        children: textSpans,
      ),
    );
  }
}
