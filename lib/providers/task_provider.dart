import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task_model.dart';
import '../models/rating_model.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';

class TaskProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();

  List<TaskModel> _allTasks = [];
  List<TaskModel> _myCreatedTasks = [];
  List<TaskModel> _myAcceptedTasks = [];
  bool _isLoading = false;
  bool _isUserInitialized = false;
  String? _errorMessage;

  StreamSubscription? _allTasksSub;
  StreamSubscription? _createdTasksSub;
  StreamSubscription? _acceptedTasksSub;

  // ── Getters ───────────────────────────────────────────────────────────────

  List<TaskModel> get allTasks => _allTasks;
  List<TaskModel> get myCreatedTasks => _myCreatedTasks;
  List<TaskModel> get myAcceptedTasks => _myAcceptedTasks;
  bool get isLoading => _isLoading;
  bool get isUserInitialized => _isUserInitialized;
  String? get errorMessage => _errorMessage;

  // ── Constructor ───────────────────────────────────────────────────────────

  TaskProvider() {
    initAllTasksStream();
  }

  // ── Initialize Streams ────────────────────────────────────────────────────

  /// Starts streaming all active tasks for the map (public stream, no auth required)
  void initAllTasksStream() {
    _allTasksSub?.cancel();
    _allTasksSub = _firestoreService.streamAllActiveTasks().listen(
      (tasks) {
        debugPrint('[TaskProvider] Received ${tasks.length} active tasks from Firestore');
        _allTasks = tasks;
        notifyListeners();
      },
      onError: (e) {
        debugPrint('[TaskProvider] streamAllActiveTasks ERROR: $e');
        _errorMessage = 'Map stream error: $e';
        notifyListeners();
      },
    );
  }

  /// Initialize streams specific to a logged in user (creator/worker tasks)
  void initUserStreams(UserModel? user) {
    if (user == null) {
      _createdTasksSub?.cancel();
      _createdTasksSub = null;
      _acceptedTasksSub?.cancel();
      _acceptedTasksSub = null;
      _myCreatedTasks = [];
      _myAcceptedTasks = [];
      _isUserInitialized = false;
      notifyListeners();
      return;
    }

    if (_isUserInitialized == true) return;
    _isUserInitialized = true;

    // Creator's tasks
    _createdTasksSub?.cancel();
    _createdTasksSub = _firestoreService
        .streamCreatorTasks(user.uid)
        .listen(
          (tasks) {
            debugPrint('[TaskProvider] Received ${tasks.length} creator tasks for user ${user.uid}');
            _myCreatedTasks = tasks;
            notifyListeners();
          },
          onError: (e) {
            debugPrint('[TaskProvider] streamCreatorTasks ERROR: $e');
            _errorMessage = 'My Tasks stream error: $e';
            notifyListeners();
          },
        );

    // Worker's accepted tasks
    _acceptedTasksSub?.cancel();
    _acceptedTasksSub = _firestoreService
        .streamWorkerTasks(user.uid)
        .listen(
          (tasks) {
            debugPrint('[TaskProvider] Received ${tasks.length} worker tasks for user ${user.uid}');
            _myAcceptedTasks = tasks;
            notifyListeners();
          },
          onError: (e) {
            debugPrint('[TaskProvider] streamWorkerTasks ERROR: $e');
          },
        );
  }

  /// Legacy helper
  void initStreams(UserModel user) {
    initAllTasksStream();
    initUserStreams(user);
  }

  void disposeStreams() {
    _allTasksSub?.cancel();
    _createdTasksSub?.cancel();
    _acceptedTasksSub?.cancel();
  }

  // ── Create Task ───────────────────────────────────────────────────────────

  Future<String?> createTask({
    required String title,
    required String description,
    required double lat,
    required double lng,
    required String locationName,
    required double minBudget,
    required double maxBudget,
    required JobCategory category,
    bool isUrgent = false,
    required UserModel creator,
    dynamic imageFile, // Uint8List on web, File on mobile
  }) async {
    _setLoading(true);
    _clearError();
    String? taskId;
    try {
      final task = TaskModel(
        id: '',
        title: title,
        description: description,
        creatorId: creator.uid,
        creatorName: creator.name,
        status: TaskStatus.open,
        category: category,
        isUrgent: isUrgent,
        location: GeoPoint(lat, lng),
        locationName: locationName,
        minBudget: minBudget,
        maxBudget: maxBudget,
        reward: 0.0, // Set when bid is accepted
        createdAt: DateTime.now(),
      );

      // ── Step 1: Write to Firestore (the critical step) ──────────────────
      taskId = await _firestoreService.createTask(task);
      debugPrint('[TaskProvider] Task written to Firestore with id: $taskId');

      // ── Step 2: Upload image (non-critical — don't fail the whole op) ──
      if (imageFile != null) {
        try {
          final imageUrl = await _storageService.uploadTaskImage(
            taskId: taskId,
            imageFile: imageFile,
          );
          await _firestoreService.updateTaskImage(taskId, imageUrl);
        } catch (imgErr) {
          debugPrint('[TaskProvider] Image upload failed (non-fatal): $imgErr');
          // Task is already written; continue without image
        }
      }

      // ── Step 3: Increment counter (non-critical) ───────────────────────
      try {
        await _firestoreService.incrementTasksPosted(creator.uid);
      } catch (counterErr) {
        debugPrint('[TaskProvider] incrementTasksPosted failed (non-fatal): $counterErr');
        // Task is already written; continue
      }

      return taskId;
    } catch (e) {
      debugPrint('[TaskProvider] createTask FAILED: $e');
      _errorMessage = 'Failed to create task: $e';
      notifyListeners();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // ── Accept Task ───────────────────────────────────────────────────────────

  Future<bool> acceptTask({
    required String taskId,
    required UserModel worker,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      await _firestoreService.acceptTask(
        taskId: taskId,
        workerId: worker.uid,
        workerName: worker.name,
        workerPhotoUrl: worker.photoUrl,
      );
      return true;
    } catch (e) {
      _errorMessage = 'Failed to accept task: $e';
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── Bidding ───────────────────────────────────────────────────────────────

  Future<bool> placeBid({
    required String taskId,
    required UserModel worker,
    required double amount,
    String? message,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      final bid = BidModel(
        id: '',
        taskId: taskId,
        workerId: worker.uid,
        workerName: worker.name,
        workerPhotoUrl: worker.photoUrl,
        workerRating: worker.ratingAverage,
        amount: amount,
        message: message,
        timestamp: DateTime.now(),
      );
      await _firestoreService.placeBid(bid);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to place bid: $e';
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Stream<List<BidModel>> streamBids(String taskId) {
    return _firestoreService.streamBids(taskId);
  }

  Future<bool> acceptBid({
    required String taskId,
    required BidModel bid,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      await _firestoreService.acceptBid(taskId: taskId, bid: bid);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to accept bid: $e';
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── Start Task ────────────────────────────────────────────────────────────

  Future<bool> startTask(String taskId) async {
    try {
      await _firestoreService.startTask(taskId);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to start task: $e';
      notifyListeners();
      return false;
    }
  }

  // ── Complete Task ─────────────────────────────────────────────────────────

  Future<bool> completeTask({
    required String taskId,
    required String workerId,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      await _firestoreService.completeTask(taskId);
      await _firestoreService.incrementTasksCompleted(workerId);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to complete task: $e';
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> cancelTask(String taskId) async {
    _setLoading(true);
    _clearError();
    try {
      await _firestoreService.cancelTask(taskId);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to cancel task: $e';
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── Rate Worker ───────────────────────────────────────────────────────────

  Future<bool> rateWorker({
    required String taskId,
    required String workerId,
    required String creatorId,
    required double stars,
    String? comment,
  }) async {
    try {
      final rating = RatingModel(
        id: '',
        taskId: taskId,
        workerId: workerId,
        creatorId: creatorId,
        stars: stars,
        comment: comment,
        timestamp: DateTime.now(),
      );
      await _firestoreService.rateWorker(rating);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to submit rating: $e';
      notifyListeners();
      return false;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  @override
  void dispose() {
    disposeStreams();
    super.dispose();
  }
}
