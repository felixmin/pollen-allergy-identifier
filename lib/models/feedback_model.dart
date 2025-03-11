class FeedbackModel {
  final String userId;
  final DateTime timestamp;
  final int symptomScore; // 0-2 scale
  final double latitude;
  final double longitude;

  FeedbackModel({
    required this.userId,
    required this.timestamp,
    required this.symptomScore,
    required this.latitude,
    required this.longitude,
  });

  // Convert to JSON for API calls
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'timestamp': timestamp.toIso8601String(),
      'symptomScore': symptomScore,
      'location': {'lat': latitude, 'lng': longitude},
    };
  }
}
