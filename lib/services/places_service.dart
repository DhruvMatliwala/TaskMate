import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class PlaceSuggestion {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  const PlaceSuggestion({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });
}

class PlaceDetails {
  final double lat;
  final double lng;
  final String formattedAddress;

  const PlaceDetails({
    required this.lat,
    required this.lng,
    required this.formattedAddress,
  });
}

class PlacesService {
  // Configured with your Google Maps API key
  static const String _apiKey = 'AIzaSyCNvK0FkShaRqSKDGyoPKQhfkf0qHHeQwY';
  static const String _baseUrl =
      'https://maps.googleapis.com/maps/api/place';

  // corsproxy.io fallback for Flutter Web CORS restrictions
  static const String _corsProxy = 'https://corsproxy.io/?';

  String _buildUrl(String endpoint, Map<String, String> params) {
    final queryString = params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
    final rawUrl = '$_baseUrl/$endpoint/json?$queryString&key=$_apiKey';

    // On web, wrap with CORS proxy
    if (kIsWeb) {
      return '$_corsProxy${Uri.encodeComponent(rawUrl)}';
    }
    return rawUrl;
  }

  // ── Autocomplete ──────────────────────────────────────────────────────────

  Future<List<PlaceSuggestion>> getAutocompleteSuggestions(
    String input, {
    String? sessionToken,
    // Bias results toward Surat, Gujarat
    String location = '21.1702,72.8311',
    int radius = 50000,
  }) async {
    if (input.isEmpty) return [];

    try {
      final params = {
        'input': input,
        'location': location,
        'radius': radius.toString(),
        'components': 'country:in',
        if (sessionToken != null) 'sessiontoken': sessionToken,
      };

      final url = _buildUrl('autocomplete', params);
      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) return [];

      final data = json.decode(response.body);
      if (data['status'] != 'OK') return [];

      return (data['predictions'] as List).map((p) {
        return PlaceSuggestion(
          placeId: p['place_id'],
          description: p['description'],
          mainText: p['structured_formatting']['main_text'] ?? '',
          secondaryText: p['structured_formatting']['secondary_text'] ?? '',
        );
      }).toList();
    } catch (e) {
      debugPrint('Places autocomplete error: $e');
      return [];
    }
  }

  // ── Place Details ─────────────────────────────────────────────────────────

  Future<PlaceDetails?> getPlaceDetails(
    String placeId, {
    String? sessionToken,
  }) async {
    try {
      final params = {
        'place_id': placeId,
        'fields': 'geometry,formatted_address',
        if (sessionToken != null) 'sessiontoken': sessionToken,
      };

      final url = _buildUrl('details', params);
      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) return null;

      final data = json.decode(response.body);
      if (data['status'] != 'OK') return null;

      final result = data['result'];
      final location = result['geometry']['location'];

      return PlaceDetails(
        lat: (location['lat'] as num).toDouble(),
        lng: (location['lng'] as num).toDouble(),
        formattedAddress: result['formatted_address'] ?? '',
      );
    } catch (e) {
      debugPrint('Place details error: $e');
      return null;
    }
  }
}
