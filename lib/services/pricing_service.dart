import '../models/task_model.dart';

class BudgetRange {
  final double min;
  final double max;
  final double suggested;

  const BudgetRange({required this.min, required this.max, required this.suggested});
}

class PricingService {
  /// Logic for reward calculation returning a range
  static BudgetRange calculateBudgetRange({
    required JobCategory category,
    required double distanceKm,
    bool isUrgent = false,
  }) {
    double baseFare = 0;
    double ratePerKm = 0;
    double durationRate = 0;
    double estimatedMinutes = 0;
    double complexityMultiplier = 1.0;

    switch (category) {
      case JobCategory.delivery:
        baseFare = 30;
        ratePerKm = 12;
        break;
      case JobCategory.grocery:
        baseFare = 40;
        ratePerKm = 12;
        baseFare += 30;
        break;
      case JobCategory.lineStanding:
        baseFare = 30;
        durationRate = 2.5;
        estimatedMinutes = 15 + (distanceKm * 2); 
        break;
      case JobCategory.physicalLabor:
        baseFare = 100;
        complexityMultiplier = 1.4;
        ratePerKm = 10;
        break;
      case JobCategory.techHelp:
        baseFare = 150;
        ratePerKm = 5;
        break;
    }

    double suggested = (baseFare + (distanceKm * ratePerKm) + (estimatedMinutes * durationRate)) * complexityMultiplier;

    if (isUrgent) {
      suggested *= 1.25;
    }

    // Round to multiples of 5
    suggested = (suggested / 5).ceil() * 5.0;
    if (suggested < 40) suggested = 40;

    // Range: -10% to +30% for room to bid
    double min = (suggested * 0.9 / 5).floor() * 5.0;
    double max = (suggested * 1.3 / 5).ceil() * 5.0;

    return BudgetRange(
      min: min < 30 ? 30 : min,
      max: max,
      suggested: suggested,
    );
  }
}
