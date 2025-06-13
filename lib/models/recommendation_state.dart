// lib/models/recommendation_state.dart

import 'package:flutter/foundation.dart';

@immutable
abstract class RecommendationState {
  const RecommendationState();
}

class RecommendationInitial extends RecommendationState {
  const RecommendationInitial();
}

class RecommendationLoading extends RecommendationState {
  const RecommendationLoading();
}

class RecommendationSuccess extends RecommendationState {
  final List<Map<String, dynamic>> data;
  const RecommendationSuccess(this.data);
}

class RecommendationError extends RecommendationState {
  final String message;
  const RecommendationError(this.message);
}
