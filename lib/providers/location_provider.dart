import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/location_service.dart';
import '../services/firestore_service.dart';

class LocationProvider extends ChangeNotifier {
  final LocationService _locationService = LocationService();
  final FirestoreService _firestoreService = FirestoreService();

  Position? _currentPosition;
  LatLng? _workerLivePosition;
  StreamSubscription<Position>? _trackingSubscription;
  StreamSubscription<Map<String, double>?>? _workerLocationSubscription;
  bool _isTracking = false;
  String? _activeTaskId; // Task being tracked (as worker)
  String? _watchingTaskId; // Task being watched (as creator)

  // ── Getters ───────────────────────────────────────────────────────────────

  Position? get currentPosition => _currentPosition;
  LatLng? get workerLivePosition => _workerLivePosition;
  bool get isTracking => _isTracking;

  LatLng get currentLatLng => _currentPosition != null
      ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
      : const LatLng(21.1702, 72.8311); // Default: Surat, Gujarat
  String? get activeTaskId => _activeTaskId;

  // ── Get Current Location (one-time) ──────────────────────────────────────

  Future<void> fetchCurrentLocation() async {
    final pos = await _locationService.getCurrentPosition();
    if (pos != null) {
      _currentPosition = pos;
      notifyListeners();
    }
  }

  // ── Worker: Start Broadcasting Live Location ──────────────────────────────

  Future<void> startTracking(String taskId) async {
    if (_isTracking) return;

    final hasPermission = await _locationService.requestPermission();
    if (!hasPermission) return;

    _activeTaskId = taskId;
    _isTracking = true;
    notifyListeners();

    _trackingSubscription?.cancel();
    _trackingSubscription = _locationService.startTracking().listen((pos) {
      _currentPosition = pos;
      notifyListeners();

      // Broadcast to Firestore
      _firestoreService.updateWorkerLocation(
        taskId: taskId,
        lat: pos.latitude,
        lng: pos.longitude,
      );
    });
  }

  /// Stop broadcasting
  void stopTracking() {
    _trackingSubscription?.cancel();
    _trackingSubscription = null;
    _isTracking = false;
    _activeTaskId = null;
    notifyListeners();
  }

  // ── Creator: Watch Worker's Live Location ─────────────────────────────────

  void startWatchingWorker(String taskId) {
    if (_watchingTaskId == taskId) return;

    _watchingTaskId = taskId;
    _workerLocationSubscription?.cancel();
    _workerLocationSubscription = _firestoreService
        .streamWorkerLocation(taskId)
        .listen((coords) {
          if (coords != null) {
            _workerLivePosition = LatLng(coords['lat']!, coords['lng']!);
            notifyListeners();
          }
        });
  }

  void stopWatchingWorker() {
    _workerLocationSubscription?.cancel();
    _workerLocationSubscription = null;
    _workerLivePosition = null;
    _watchingTaskId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stopTracking();
    stopWatchingWorker();
    super.dispose();
  }
}
