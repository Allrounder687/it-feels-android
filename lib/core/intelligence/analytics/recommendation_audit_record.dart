import 'package:flutter/foundation.dart';

/// Telemetry record capturing detailed ranking decisions for explainability and observability.
/// Implements Section 17 (Telemetry & Observability).
@immutable
class RecommendationAuditRecord {
  final String recommendationId;
  final String trackId;
  final String candidateSource; // e.g. 'favorites_cluster', 'high_affinity_artists', 'genre_seeds'
  final String rankingVersion;   // e.g. 'v1.0-deterministic'
  final Map<String, double> scoreComponents; // artistAffinity, genreAffinity, moodMatch, recencyScore, noveltyBoost, repetitionPenalty
  final double finalScore;
  final List<String> appliedFilters; // e.g. 'exclusion_filter', 'artist_cap_filter', 'explicit_blocklist'
  final Map<String, dynamic> recommendationContext; // session length, active genre capsule, time of day
  final DateTime timestamp;

  const RecommendationAuditRecord({
    required this.recommendationId,
    required this.trackId,
    required this.candidateSource,
    required this.rankingVersion,
    required this.scoreComponents,
    required this.finalScore,
    required this.appliedFilters,
    required this.recommendationContext,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'recommendation_id': recommendationId,
    'track_id': trackId,
    'candidate_source': candidateSource,
    'ranking_version': rankingVersion,
    'score_components': scoreComponents,
    'final_score': finalScore,
    'applied_filters': appliedFilters,
    'recommendation_context': recommendationContext,
    'timestamp': timestamp.toIso8601String(),
  };

  factory RecommendationAuditRecord.fromJson(Map<String, dynamic> json) => RecommendationAuditRecord(
    recommendationId: json['recommendation_id'] as String,
    trackId: json['track_id'] as String,
    candidateSource: json['candidate_source'] as String,
    rankingVersion: json['ranking_version'] as String,
    scoreComponents: (json['score_components'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, (v as num).toDouble()),
        ) ?? {},
    finalScore: (json['final_score'] as num?)?.toDouble() ?? 0.0,
    appliedFilters: (json['applied_filters'] as List<dynamic>?)?.cast<String>() ?? [],
    recommendationContext: (json['recommendation_context'] as Map<String, dynamic>?) ?? {},
    timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp'] as String) : DateTime.now(),
  );

  @override
  String toString() => 'RecommendationAuditRecord($recommendationId, track: $trackId, score: $finalScore, source: $candidateSource)';
}
