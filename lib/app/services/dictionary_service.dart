import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sub3/app/models/dictionary_entry.dart';

class DictionaryService {
  static const String _baseUrl =
      'https://freedictionaryapi.com/api/v1/entries/en';
  final Map<String, DictionaryEntry> _cache = {};

  /// Fetch word definition from the Dictionary API
  /// Returns null if word is not found or on error
  Future<DictionaryEntry?> fetchWordDefinition(String word) async {
    final cleanWord = word.trim().toLowerCase();

    // Check cache first
    if (_cache.containsKey(cleanWord)) {
      return _cache[cleanWord];
    }

    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/$cleanWord'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final entries = decoded['entries'] as List<dynamic>?;
          // If entries is empty, word was not found
          if (entries != null && entries.isNotEmpty) {
            final entry = DictionaryEntry.fromJson(decoded);
            _cache[cleanWord] = entry;
            return entry;
          }
          if (entries == null && decoded['word'] != null) {
            final entry = DictionaryEntry.fromJson(decoded);
            _cache[cleanWord] = entry;
            return entry;
          }
        } else if (decoded is List && decoded.isNotEmpty) {
          final entry =
              DictionaryEntry.fromJson(decoded[0] as Map<String, dynamic>);
          _cache[cleanWord] = entry;
          return entry;
        }
      } else if (response.statusCode == 404) {
        // Word not found
        return null;
      }
    } catch (e) {
      // Log error in debug mode
      debugPrint('Dictionary API error: $e');
      return null;
    }

    return null;
  }

  /// Clear the cache (useful for resetting between sessions)
  void clearCache() {
    _cache.clear();
  }

  /// Get cache size (for debugging)
  int getCacheSize() {
    return _cache.length;
  }
}
