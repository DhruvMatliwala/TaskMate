import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class RouteInfo {
  final double distanceKm;
  final String distanceText;
  final int durationMinutes;
  final String durationText;
  final List<LatLng> polylinePoints;

  const RouteInfo({
    required this.distanceKm,
    required this.distanceText,
    required this.durationMinutes,
    required this.durationText,
    required this.polylinePoints,
  });
}

class DirectionsService {
  /// Calculate straight-line distance in kilometers
  static double getDistanceKm(LatLng start, LatLng end) {
    final meters = Geolocator.distanceBetween(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    );
    return meters / 1000.0;
  }

  /// Format distance into user-friendly text
  static String formatDistance(double km) {
    if (km < 1.0) {
      final meters = (km * 1000).round();
      return '$meters m';
    }
    return '${km.toStringAsFixed(1)} km';
  }

  /// Calculate ETA duration in minutes assuming average city speed (~25-30 km/h)
  static int estimateDurationMinutes(double distanceKm) {
    const avgSpeedKmH = 25.0; // average city transit/bike/car speed
    final minutes = ((distanceKm / avgSpeedKmH) * 60).ceil();
    return minutes < 1 ? 1 : minutes;
  }

  /// Format duration into user-friendly text
  static String formatDuration(int minutes) {
    if (minutes < 60) {
      return '$minutes mins';
    }
    final hours = minutes ~/ 60;
    final remainingMins = minutes % 60;
    return remainingMins > 0 ? '${hours}h ${remainingMins}m' : '${hours}h';
  }

  /// Fetch realistic road route coordinates using open routing service (with fallback)
  static Future<RouteInfo> getRoute(LatLng origin, LatLng destination) async {
    final directDistance = getDistanceKm(origin, destination);
    final directDuration = estimateDurationMinutes(directDistance);

    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}?overview=full&geometries=geojson',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          final distanceMeters = (route['distance'] as num?)?.toDouble() ?? (directDistance * 1000);
          final durationSecs = (route['duration'] as num?)?.toDouble() ?? (directDuration * 60.0);

          final coordinates = route['geometry']['coordinates'] as List;
          final polyline = coordinates.map<LatLng>((coord) {
            return LatLng(
              (coord[1] as num).toDouble(),
              (coord[0] as num).toDouble(),
            );
          }).toList();

          final km = distanceMeters / 1000.0;
          final mins = (durationSecs / 60.0).ceil();

          return RouteInfo(
            distanceKm: km,
            distanceText: formatDistance(km),
            durationMinutes: mins,
            durationText: formatDuration(mins),
            polylinePoints: polyline,
          );
        }
      }
    } catch (e) {
      debugPrint('[DirectionsService] OSRM route fetch fallback: $e');
    }

    // Fallback: direct line with straight-line calculation
    return RouteInfo(
      distanceKm: directDistance,
      distanceText: formatDistance(directDistance),
      durationMinutes: directDuration,
      durationText: formatDuration(directDuration),
      polylinePoints: [origin, destination],
    );
  }

  /// Open external turn-by-turn navigation in Google Maps
  static Future<bool> openGoogleMapsNavigation({
    required double destLat,
    required double destLng,
    double? originLat,
    double? originLng,
    String? destName,
  }) async {
    Uri googleMapsUrl;
    if (originLat != null && originLng != null) {
      // Direct origin-to-destination route URL - loads full directions immediately
      googleMapsUrl = Uri.parse(
        'https://www.google.com/maps/dir/$originLat,$originLng/$destLat,$destLng',
      );
    } else {
      googleMapsUrl = Uri.https('www.google.com', '/maps/dir/', {
        'api': '1',
        'destination': '$destLat,$destLng',
        'travelmode': 'driving',
      });
    }

    try {
      debugPrint('[DirectionsService] Launching Google Maps directions: $googleMapsUrl');
      return await launchUrl(
        googleMapsUrl,
        mode: LaunchMode.platformDefault,
        webOnlyWindowName: '_blank',
      );
    } catch (e) {
      debugPrint('[DirectionsService] Failed to open Google Maps: $e');
      return false;
    }
  }
}
