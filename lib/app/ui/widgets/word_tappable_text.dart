import 'package:flutter/material.dart';
import 'package:sub3/app/ui/widgets/dictionary_bottom_sheet.dart';

class WordTappableText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final bool enabled;

  const WordTappableText(
    this.text, {
    super.key,
    this.style,
    this.enabled = true,
  });

  List<String> _tokenizeWords(String text) {
    // Split by whitespace and punctuation
    final regex = RegExp(r'\b\w+\b');
    final matches = regex.allMatches(text);
    final words = <String>[];
    var lastEnd = 0;

    for (final match in matches) {
      // Add non-word content before the word
      if (match.start > lastEnd) {
        words.add(text.substring(lastEnd, match.start));
      }
      // Add the word
      words.add(match.group(0)!);
      lastEnd = match.end;
    }

    // Add any remaining non-word content
    if (lastEnd < text.length) {
      words.add(text.substring(lastEnd));
    }

    return words;
  }

  void _showDictionary(BuildContext context, String word) {
    if (!enabled) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DictionaryBottomSheet(word: word),
    );
  }

  bool _isWord(String token) {
    return RegExp(r'^\w+$').hasMatch(token);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = _tokenizeWords(text);

    return Wrap(
      children: tokens.map((token) {
        if (_isWord(token)) {
          return GestureDetector(
            onTap: enabled ? () => _showDictionary(context, token) : null,
            child: Container(
              decoration: BoxDecoration(
                border: enabled
                    ? Border(
                        bottom: BorderSide(
                          color: Theme.of(context).primaryColor,
                          width: 0.5,
                        ),
                      )
                    : null,
              ),
              child: Text(
                token,
                style: (style ?? const TextStyle()).copyWith(
                  color: enabled
                      ? Colors.white
                      : null,
                ),
              ),
            ),
          );
        } else {
          return Text(token, style: style);
        }
      }).toList(),
    );
  }
}
