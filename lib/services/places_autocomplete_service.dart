import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Fetches address/location suggestions from Google Places Autocomplete (Legacy)
/// restricted to India only.
class PlacesAutocompleteService {
  static const String _baseUrl =
      'https://maps.googleapis.com/maps/api/place/autocomplete/json';

  static String? get _apiKey =>
      dotenv.env['GOOGLE_PLACES_API_KEY']?.trim().isNotEmpty == true
          ? dotenv.env['GOOGLE_PLACES_API_KEY']
          : null;

  /// Returns list of suggestion strings (description) for [input], India only.
  /// Returns empty list if API key is missing or on error.
  static Future<List<String>> getSuggestions(String input) async {
    final key = _apiKey;
    if (key == null) return [];

    final trimmed = input.trim();
    if (trimmed.length < 2) return [];

    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        'input': trimmed,
        'components': 'country:in',
        'key': key,
        'language': 'en',
      },
    );

    try {
      final response = await http.get(uri).timeout(
            const Duration(seconds: 8),
            onTimeout: () => http.Response('', 408),
          );
      if (response.statusCode != 200) return [];

      final json = jsonDecode(response.body) as Map<String, dynamic>?;
      if (json == null) return [];

      final status = json['status'] as String?;
      if (status != 'OK' && status != 'ZERO_RESULTS') return [];

      final predictions = json['predictions'];
      if (predictions is! List) return [];

      final list = <String>[];
      for (final p in predictions) {
        if (p is Map<String, dynamic>) {
          final desc = p['description'] as String?;
          if (desc != null && desc.trim().isNotEmpty) {
            list.add(desc.trim());
          }
        }
      }
      return list;
    } catch (_) {
      return [];
    }
  }
}
