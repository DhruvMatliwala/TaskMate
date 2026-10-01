import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../models/task_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/chat_provider.dart';
import '../../services/places_service.dart';
import '../../services/directions_service.dart';
import '../../widgets/common/glass_card.dart';
import '../../widgets/common/shimmer_loader.dart';
import '../../widgets/map/custom_marker_painter.dart';
import '../tasks/create_task_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // Map controller
  GoogleMapController? _mapController;

  // Default camera: Surat, Gujarat
  static const CameraPosition _suratCamera = CameraPosition(
    target: LatLng(21.1702, 72.8311),
    zoom: 13.0,
  );

  // Map state
  final Map<MarkerId, Marker> _markers = {};
  final Map<PolylineId, Polyline> _polylines = {};
  bool _mapLoaded = false;

  // Active Route state
  RouteInfo? _activeRoute;
  TaskModel? _navigatingTask;
  bool _isLiveNavigating = false;

  // Search
  final _searchController = TextEditingController();
  final _placesService = PlacesService();
  List<PlaceSuggestion> _suggestions = [];
  bool _showSuggestions = false;
  Timer? _debounceTimer;
  String? _sessionToken;

  // Bottom sheet task
  // ignore: unused_field
  TaskModel? _selectedTask;

  // Animation
  late AnimationController _searchAnimController;
  late Animation<double> _searchFade;

  String _lastMarkerFingerprint = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _searchAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _searchFade = CurvedAnimation(
      parent: _searchAnimController,
      curve: Curves.easeOut,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initProviders();
      // Listen to task changes to update markers
      context.read<TaskProvider>().addListener(_onTasksChanged);
    });
  }

  // ── Android Activity Lifecycle Handlers ────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    debugPrint('[Activity Lifecycle] State transition: $state');

    switch (state) {
      case AppLifecycleState.resumed:
        // Android onResume: App is brought to foreground.
        // Refresh GPS position and sync live task/chat streams.
        debugPrint('[Activity Lifecycle] onResume: App in foreground. Refreshing GPS & streams.');
        if (mounted) {
          context.read<LocationProvider>().fetchCurrentLocation();
          final auth = context.read<AuthProvider>();
          if (auth.userModel != null) {
            context.read<ChatProvider>().initInbox(auth.userModel!.uid);
          }
        }
        break;

      case AppLifecycleState.inactive:
        // Android onPause: Screen partially obscured or transitioning.
        debugPrint('[Activity Lifecycle] onPause: Screen transition / notification overlay.');
        break;

      case AppLifecycleState.paused:
        // Android onStop: App minimized to background.
        // Conserve battery by throttling background location tracking if not navigating.
        debugPrint('[Activity Lifecycle] onStop: App minimized to background. Conserving resources.');
        break;

      case AppLifecycleState.detached:
        // Android onDestroy: Flutter engine detaching from host MainActivity.
        debugPrint('[Activity Lifecycle] onDestroy: Engine detaching from MainActivity.');
        break;

      case AppLifecycleState.hidden:
        break;
    }
  }

  void _initProviders() {
    final auth = context.read<AuthProvider>();
    final taskProv = context.read<TaskProvider>();
    taskProv.initAllTasksStream();
    if (auth.userModel != null) {
      taskProv.initUserStreams(auth.userModel);
      context.read<ChatProvider>().initInbox(auth.userModel!.uid);
    }
    context.read<LocationProvider>().fetchCurrentLocation();
  }

  void _onTasksChanged() {
    if (mounted == false) return;
    final tasks = context.read<TaskProvider>().allTasks;
    _updateMarkers(tasks);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Remove listener before disposing
    try {
      context.read<TaskProvider>().removeListener(_onTasksChanged);
    } catch (_) {}
    _searchController.dispose();
    _debounceTimer?.cancel();
    _searchAnimController.dispose();
    super.dispose();
  }

  // ── Map Setup ─────────────────────────────────────────────────────────────

  Future<void> _onMapCreated(GoogleMapController controller) async {
    _mapController = controller;
    setState(() => _mapLoaded = true);

    // Initial marker sync
    if (mounted == false) return;
    final tasks = context.read<TaskProvider>().allTasks;
    if (tasks.isNotEmpty) {
      _updateMarkers(tasks);
    }

    // Move to user's current location if available
    if (mounted == false) return;
    final locProvider = context.read<LocationProvider>();
    if (locProvider.currentPosition != null) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(locProvider.currentLatLng),
      );
    }
  }

  // ── Markers ───────────────────────────────────────────────────────────────

  Future<void> _updateMarkers(List<TaskModel> tasks, [dynamic currentPosition]) async {
    final fingerprint = tasks.map((t) => '${t.id}_${t.status.name}_${t.location.latitude}_${t.location.longitude}').join('|');
    if (fingerprint == _lastMarkerFingerprint && _markers.isNotEmpty) {
      return;
    }
    _lastMarkerFingerprint = fingerprint;

    final newMarkers = <MarkerId, Marker>{};

    for (final task in tasks) {
      final markerId = MarkerId(task.id);
      
      // Use category color for better distinction on map
      final color = task.category.color;
      final icon = task.category.icon;

      BitmapDescriptor markerIcon;
      try {
        markerIcon = await createCustomMarker(color: color, icon: icon);
      } catch (e) {
        debugPrint('[HomeScreen] createCustomMarker fallback: $e');
        markerIcon = BitmapDescriptor.defaultMarkerWithHue(
          task.isOpen == true
              ? BitmapDescriptor.hueGreen
              : task.isAccepted == true
                  ? BitmapDescriptor.hueYellow
                  : task.isInProgress == true
                      ? BitmapDescriptor.hueViolet
                      : BitmapDescriptor.hueAzure,
        );
      }

      newMarkers[markerId] = Marker(
        markerId: markerId,
        position: LatLng(
          task.location.latitude,
          task.location.longitude,
        ),
        icon: markerIcon,
        infoWindow: InfoWindow(title: task.title, snippet: '₹${task.reward.toStringAsFixed(0)}'),
        onTap: () => _onMarkerTapped(task),
      );
    }

    if (mounted) {
      setState(() {
        _markers
          ..clear()
          ..addAll(newMarkers);
      });
      debugPrint('[HomeScreen] Updated map markers: ${_markers.length} markers active');
    }
  }

  void _onMarkerTapped(TaskModel task) {
    setState(() => _selectedTask = task);
    _showTaskBottomSheet(task);
  }

  // ── Route & Navigation ────────────────────────────────────────────────────

  Future<void> _plotRouteToTask(TaskModel task) async {
    final locProv = context.read<LocationProvider>();
    final origin = locProv.currentLatLng;
    final destination = LatLng(task.location.latitude, task.location.longitude);

    final route = await DirectionsService.getRoute(origin, destination);
    if (!mounted) return;

    const polylineId = PolylineId('active_task_route');
    final polyline = Polyline(
      polylineId: polylineId,
      points: route.polylinePoints,
      color: const Color(0xFF38F9D7),
      width: 5,
      startCap: Cap.roundCap,
      endCap: Cap.roundCap,
    );

    setState(() {
      _polylines[polylineId] = polyline;
      _activeRoute = route;
      _navigatingTask = task;
    });

    // Animate camera to fit both origin and destination with padding
    final minLat = min(origin.latitude, destination.latitude);
    final maxLat = max(origin.latitude, destination.latitude);
    final minLng = min(origin.longitude, destination.longitude);
    final maxLng = max(origin.longitude, destination.longitude);

    // If points are very close, use a single center zoom
    if ((maxLat - minLat).abs() < 0.002 && (maxLng - minLng).abs() < 0.002) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(destination, 15),
      );
    } else {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          90,
        ),
      );
    }
  }

  void _clearActiveRoute() {
    setState(() {
      _polylines.remove(const PolylineId('active_task_route'));
      _activeRoute = null;
      _navigatingTask = null;
      _isLiveNavigating = false;
    });
  }

  void _startLiveNavigation() {
    if (_navigatingTask == null) return;
    final locProv = context.read<LocationProvider>();
    final userPos = locProv.currentLatLng;

    setState(() {
      _isLiveNavigating = true;
    });

    // Animate map into high-zoom 3D navigation perspective
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: userPos,
          zoom: 17.0,
          tilt: 40.0,
        ),
      ),
    );

    // Open exact Google Maps route in new tab
    DirectionsService.openGoogleMapsNavigation(
      originLat: userPos.latitude,
      originLng: userPos.longitude,
      destLat: _navigatingTask!.location.latitude,
      destLng: _navigatingTask!.location.longitude,
      destName: _navigatingTask!.locationName,
    );
  }

  // ── Live Tracking Polyline ────────────────────────────────────────────────

  void _updatePolyline(LatLng workerPosition, LatLng destination) {
    const polylineId = PolylineId('worker_to_task');
    final polyline = Polyline(
      polylineId: polylineId,
      points: [workerPosition, destination],
      color: const Color(0xFF6C63FF),
      width: 4,
      patterns: [PatternItem.dash(20), PatternItem.gap(10)],
    );

    setState(() {
      _polylines[polylineId] = polyline;
    });
  }

  // ── Search ────────────────────────────────────────────────────────────────

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    _sessionToken ??= DateTime.now().millisecondsSinceEpoch.toString();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
      final results = await _placesService.getAutocompleteSuggestions(
        value,
        sessionToken: _sessionToken,
      );
      if (mounted == true) {
        setState(() {
          _suggestions = results;
          _showSuggestions = results.isNotEmpty;
        });
        if (results.isNotEmpty) _searchAnimController.forward();
      }
    });
  }

  Future<void> _onSuggestionSelected(PlaceSuggestion suggestion) async {
    _searchController.text = suggestion.mainText;
    setState(() => _showSuggestions = false);
    _searchAnimController.reset();

    final details = await _placesService.getPlaceDetails(
      suggestion.placeId,
      sessionToken: _sessionToken,
    );
    _sessionToken = null;

    if (details != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(details.lat, details.lng), 15),
      );
    }
  }

  // ── Bottom Sheet ──────────────────────────────────────────────────────────

  void _showTaskBottomSheet(TaskModel task) {
    final userLatLng = context.read<LocationProvider>().currentLatLng;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _TaskPreviewSheet(
        task: task,
        userLatLng: userLatLng,
        onShowRoute: () {
          Navigator.pop(context);
          _plotRouteToTask(task);
        },
        onViewDetails: () {
          Navigator.pop(context);
          Navigator.pushNamed(context, '/task-detail', arguments: task);
        },
      ),
    );
  }

  Set<Marker> _buildMapMarkers(LocationProvider locProvider) {
    final markers = <Marker>{};
    markers.addAll(_markers.values);

    if (locProvider.currentPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('_my_location'),
          position: locProvider.currentLatLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          infoWindow: const InfoWindow(title: 'You are here'),
          zIndexInt: 10,
        ),
      );
    }
    return markers;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.userModel;
    final taskProvider = context.watch<TaskProvider>();
    final locProvider = context.watch<LocationProvider>();

    // Ensure user streams & inbox are in sync whenever user logs in
    if (user != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted == true) {
          final p = Provider.of<TaskProvider>(context, listen: false);
          if (p.isUserInitialized == false) p.initUserStreams(user);
          Provider.of<ChatProvider>(context, listen: false).initInbox(user.uid);
        }
      });
    }

    // Update polyline for in-progress task (creator view)
    if (user != null && user.isCreator == true && locProvider.workerLivePosition != null) {
      for (final task in taskProvider.myCreatedTasks) {
        if (task.isInProgress == true) {
          _updatePolyline(
            locProvider.workerLivePosition!,
            LatLng(task.location.latitude, task.location.longitude),
          );
          break;
        }
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      drawer: _buildDrawer(user),
      body: Stack(
        children: [
          // ── Google Map ──────────────────────────────────────────────────
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: _suratCamera,
            style: _darkMapStyle,
            markers: _buildMapMarkers(locProvider),
            polylines: Set<Polyline>.from(_polylines.values),
            myLocationEnabled: false, // Not reliable on Flutter Web
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          if (_mapLoaded == false) const ShimmerMapOverlay(),

          // ── Search Bar / Live Navigation HUD ─────────────────────────────
          SafeArea(
            child: Column(
              children: [
                if (_isLiveNavigating == true && _navigatingTask != null && _activeRoute != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 580),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF38F9D7), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF38F9D7).withValues(alpha: 0.2),
                                blurRadius: 16,
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF38F9D7),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.navigation_rounded, color: Color(0xFF0F0F1A), size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        const Text(
                                          'LIVE GPS NAVIGATION',
                                          style: TextStyle(
                                            color: Color(0xFF38F9D7),
                                            fontWeight: FontWeight.w800,
                                            fontSize: 11,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '• ${_activeRoute!.durationText}',
                                          style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _navigatingTask!.locationName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                                onPressed: () => setState(() => _isLiveNavigating = false),
                                tooltip: 'Exit Navigation View',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                else ...[
                  // Top bar: hamburger + search + profile
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      children: [
                        // Menu button
                        Builder(
                          builder: (ctx) => GlassCard(
                            padding: const EdgeInsets.all(10),
                            width: 46,
                            height: 46,
                            child: const Icon(
                              Icons.menu_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                            onTap: () => Scaffold.of(ctx).openDrawer(),
                          ),
                        ),

                        const SizedBox(width: 10),

                        // Search field
                        Expanded(
                          child: GlassCard(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 0,
                            ),
                            height: 46,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.search,
                                  color: Color(0xFF9E9E9E),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    onChanged: _onSearchChanged,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                    decoration: const InputDecoration(
                                      hintText: 'Search a location...',
                                      hintStyle: TextStyle(
                                        color: Color(0xFF4A4A6A),
                                        fontSize: 14,
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                                if (_searchController.text.isNotEmpty)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.clear,
                                      color: Color(0xFF9E9E9E),
                                      size: 16,
                                    ),
                                    onPressed: () {
                                      _searchController.clear();
                                      _onSearchChanged('');
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(width: 10),

                        // Messages / Inbox button with live unread badge
                        Consumer<ChatProvider>(
                          builder: (context, chatProv, _) {
                            final unreadCount = chatProv.totalUnreadCount;
                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                GlassCard(
                                  padding: const EdgeInsets.all(0),
                                  width: 46,
                                  height: 46,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () => Navigator.pushNamed(context, '/inbox'),
                                    child: const Center(
                                      child: Icon(
                                        Icons.chat_bubble_outline_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                                if (unreadCount > 0)
                                  Positioned(
                                    top: -3,
                                    right: -3,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF6584),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFF0F0F1A), width: 1.5),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0xFFFF6584),
                                            blurRadius: 6,
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        unreadCount > 9 ? '9+' : '$unreadCount',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),

                        const SizedBox(width: 10),

                        // Profile button
                        GlassCard(
                          padding: const EdgeInsets.all(0),
                          width: 46,
                          height: 46,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => Navigator.pushNamed(context, '/profile'),
                            child: Center(
                              child: user?.photoUrl != null
                                  ? CircleAvatar(
                                      radius: 16,
                                      backgroundImage: NetworkImage(
                                        user!.photoUrl!,
                                      ),
                                    )
                                  : Text(
                                      user?.name.isNotEmpty == true
                                          ? user!.name[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        color: Color(0xFF6C63FF),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Autocomplete suggestions dropdown
                  if (_showSuggestions == true && _suggestions.isNotEmpty)
                    FadeTransition(
                      opacity: _searchFade,
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A2E),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF2D2D4E),
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black45,
                              blurRadius: 16,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          itemCount: _suggestions.length,
                          separatorBuilder: (_, __) => const Divider(
                            color: Color(0xFF2D2D4E),
                            height: 1,
                          ),
                          itemBuilder: (context, index) {
                            final item = _suggestions[index];
                            return ListTile(
                              leading: const Icon(
                                Icons.location_on_outlined,
                                color: Color(0xFF6C63FF),
                                size: 18,
                              ),
                              title: Text(
                                item.mainText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(
                                item.secondaryText,
                                style: const TextStyle(
                                  color: Color(0xFF9E9E9E),
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              dense: true,
                              onTap: () => _onSuggestionSelected(item),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),

          // ── Map Legend ──────────────────────────────────────────────────
          Positioned(
            bottom: 100,
            right: 16,
            child: Column(
              children: [
                _MapControlButton(
                  icon: Icons.my_location,
                  onTap: () async {
                    // Request location and pan map to user's real position
                    final locProv = context.read<LocationProvider>();
                    await locProv.fetchCurrentLocation();
                    if (mounted == true) {
                      final pos = locProv.currentLatLng;
                      _mapController?.animateCamera(
                        CameraUpdate.newLatLngZoom(pos, 15),
                      );
                    }
                  },
                ),
                const SizedBox(height: 8),
                _MapControlButton(
                  icon: Icons.add,
                  onTap: () {
                    _mapController?.animateCamera(CameraUpdate.zoomIn());
                  },
                ),
                const SizedBox(height: 8),
                _MapControlButton(
                  icon: Icons.remove,
                  onTap: () {
                    _mapController?.animateCamera(CameraUpdate.zoomOut());
                  },
                ),
              ],
            ),
          ),

          // ── Bottom HUD: Active Route Navigation or Task Count Chip ────────
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: _activeRoute != null && _navigatingTask != null
                ? _ActiveRouteHUD(
                    task: _navigatingTask!,
                    route: _activeRoute!,
                    isLiveNavigating: _isLiveNavigating,
                    onNavigate: _startLiveNavigation,
                    onViewDetails: () => Navigator.pushNamed(
                      context,
                      '/task-detail',
                      arguments: _navigatingTask,
                    ),
                    onClose: _clearActiveRoute,
                  )
                : Center(
                    child: GlassCard(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.task_alt, color: Color(0xFF43E97B), size: 16),
                          const SizedBox(width: 8),
                          Text(
                            '${taskProvider.allTasks.where((t) => t.isOpen == true).length} open tasks nearby',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),

      // ── FAB: Create Task ─────────────────────────────────────────────────
      floatingActionButton: user != null && _activeRoute == null
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateTaskScreen()),
              ),
              backgroundColor: const Color(0xFF6C63FF),
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text(
                'Post Task',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              elevation: 8,
            )
          : null,
    );
  }

  // ── Navigation Drawer ─────────────────────────────────────────────────────

  Widget _buildDrawer(UserModel? user) {
    return Drawer(
      backgroundColor: const Color(0xFF0F0F1A),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: const Color(0xFF6C63FF).withValues(alpha: 0.2),
                    backgroundImage: user?.photoUrl != null
                        ? NetworkImage(user!.photoUrl!)
                        : null,
                    child: user?.photoUrl == null
                        ? Text(
                            user?.name.isNotEmpty == true
                                ? user!.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Color(0xFF6C63FF),
                              fontWeight: FontWeight.w700,
                              fontSize: 22,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'User',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          user?.roleDisplayName ?? '',
                          style: TextStyle(
                            color: user?.isDualRole == true
                                ? const Color(0xFF6C63FF)
                                : (user?.isWorker == true
                                    ? const Color(0xFF43E97B)
                                    : const Color(0xFFFF6584)),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(color: Color(0xFF2D2D4E), height: 1),
            const SizedBox(height: 8),

            _DrawerItem(
              icon: Icons.map_outlined,
              label: 'Map',
              onTap: () => Navigator.pop(context),
            ),
            _DrawerItem(
              icon: Icons.list_alt_outlined,
              label: 'My Tasks',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/my-tasks');
              },
            ),
            Consumer<ChatProvider>(
              builder: (context, chatProv, _) => _DrawerItem(
                icon: Icons.chat_bubble_outline_rounded,
                label: 'Messages',
                badgeCount: chatProv.totalUnreadCount,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/inbox');
                },
              ),
            ),
            _DrawerItem(
              icon: Icons.person_outline,
              label: 'Profile',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/profile');
              },
            ),

            const Spacer(),
            const Divider(color: Color(0xFF2D2D4E), height: 1),

            _DrawerItem(
              icon: Icons.logout_rounded,
              label: 'Sign Out',
              color: const Color(0xFFFF6584),
              onTap: () async {
                Navigator.pop(context);
                await context.read<AuthProvider>().signOut();
                if (mounted == true) Navigator.pushReplacementNamed(context, '/login');
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ── Helper Widgets ────────────────────────────────────────────────────────────

class _ActiveRouteHUD extends StatelessWidget {
  final TaskModel task;
  final RouteInfo route;
  final bool isLiveNavigating;
  final VoidCallback onNavigate;
  final VoidCallback onViewDetails;
  final VoidCallback onClose;

  const _ActiveRouteHUD({
    required this.task,
    required this.route,
    this.isLiveNavigating = false,
    required this.onNavigate,
    required this.onViewDetails,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF38F9D7).withValues(alpha: 0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF38F9D7).withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38F9D7).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.directions_car_rounded, color: Color(0xFF38F9D7), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              route.distanceText,
                              style: const TextStyle(
                                color: Color(0xFF38F9D7),
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '•  ${route.durationText}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          task.locationName.isNotEmpty ? task.locationName : task.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF6A6A8A), size: 20),
                    onPressed: onClose,
                    tooltip: 'Clear Route',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: ElevatedButton.icon(
                      onPressed: onNavigate,
                      icon: Icon(
                        isLiveNavigating ? Icons.open_in_new_rounded : Icons.navigation_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                      label: Text(
                        isLiveNavigating ? 'Open Google Maps ↗' : 'Start Navigation',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isLiveNavigating ? const Color(0xFF10B981) : const Color(0xFF6C63FF),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: OutlinedButton(
                      onPressed: onViewDetails,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF2D2D4E)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'Task Details',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MapControlButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      width: 44,
      height: 44,
      padding: const EdgeInsets.all(0),
      onTap: onTap,
      child: Center(
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final int badgeCount;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.white;
    return ListTile(
      leading: Icon(icon, color: c, size: 22),
      title: Text(
        label,
        style: TextStyle(
          color: c,
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
      ),
      trailing: badgeCount > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6584),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badgeCount > 9 ? '9+' : '$badgeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : null,
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      hoverColor: Colors.white.withValues(alpha: 0.05),
    );
  }
}

class _TaskPreviewSheet extends StatelessWidget {
  final TaskModel task;
  final LatLng userLatLng;
  final VoidCallback onShowRoute;
  final VoidCallback onViewDetails;

  const _TaskPreviewSheet({
    required this.task,
    required this.userLatLng,
    required this.onShowRoute,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final distKm = DirectionsService.getDistanceKm(
      userLatLng,
      LatLng(task.location.latitude, task.location.longitude),
    );
    final distText = DirectionsService.formatDistance(distKm);
    final etaText = DirectionsService.formatDuration(DirectionsService.estimateDurationMinutes(distKm));

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF2D2D4E)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (task.isUrgent == true)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.bolt_rounded, color: Color(0xFFFF6584), size: 20),
                ),
              Expanded(
                child: Text(
                  task.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF43E97B), Color(0xFF38F9D7)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '₹${task.reward.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Category & Distance & ETA badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: task.category.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: task.category.color.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(task.category.icon, color: task.category.color, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      task.category.displayName,
                      style: TextStyle(color: task.category.color, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF38F9D7).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF38F9D7).withValues(alpha: 0.3)),
                ),
                child: Text(
                  '$distText  ($etaText)',
                  style: const TextStyle(color: Color(0xFF38F9D7), fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            task.description,
            style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 13, height: 1.4),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onShowRoute,
                  icon: const Icon(Icons.alt_route_rounded, size: 16, color: Color(0xFF38F9D7)),
                  label: const Text(
                    'View Route',
                    style: TextStyle(color: Color(0xFF38F9D7), fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: const Color(0xFF38F9D7).withValues(alpha: 0.4)),
                    backgroundColor: const Color(0xFF38F9D7).withValues(alpha: 0.08),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onViewDetails,
                  icon: const Icon(Icons.info_outline, size: 16, color: Colors.white),
                  label: const Text(
                    'Details',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Dark Map Style JSON ───────────────────────────────────────────────────────

const String _darkMapStyle = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#0f0f1a"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#6b7280"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#0f0f1a"}]},
  {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#1a1a2e"}]},
  {"featureType": "road", "elementType": "geometry.stroke", "stylers": [{"color": "#212121"}]},
  {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#2d2d4e"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#0a0a1a"}]},
  {"featureType": "poi", "elementType": "geometry", "stylers": [{"color": "#15152a"}]},
  {"featureType": "transit", "elementType": "geometry", "stylers": [{"color": "#1a1a2e"}]},
  {"featureType": "administrative", "elementType": "geometry", "stylers": [{"color": "#2d2d4e"}]},
  {"featureType": "administrative.country", "elementType": "labels.text.fill", "stylers": [{"color": "#9ca3af"}]},
  {"featureType": "administrative.locality", "elementType": "labels.text.fill", "stylers": [{"color": "#d1d5db"}]}
]
''';
