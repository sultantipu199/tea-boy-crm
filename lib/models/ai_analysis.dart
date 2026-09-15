class AiAnalysis {
  final String sentiment;
  final List<String> painPoints;
  final String recommendedAction;
  final String followUpMessage;
  final String nextFollowUpDate;
  final int dealScore;

  AiAnalysis({
    required this.sentiment,
    required this.painPoints,
    required this.recommendedAction,
    required this.followUpMessage,
    required this.nextFollowUpDate,
    required this.dealScore,
  });

  factory AiAnalysis.fromJson(Map<String, dynamic> json) {
    return AiAnalysis(
      sentiment: json['sentiment']?.toString() ?? 'Neutral',
      painPoints: (json['pain_points'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      recommendedAction:
          json['recommended_action']?.toString() ?? 'Follow up via WhatsApp',
      followUpMessage: json['follow_up_message']?.toString() ?? '',
      nextFollowUpDate: json['next_follow_up_date']?.toString() ?? '',
      dealScore: (json['deal_score'] is num)
          ? (json['deal_score'] as num).toInt()
          : int.tryParse(json['deal_score']?.toString() ?? '50') ?? 50,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sentiment': sentiment,
      'pain_points': painPoints,
      'recommended_action': recommendedAction,
      'follow_up_message': followUpMessage,
      'next_follow_up_date': nextFollowUpDate,
      'deal_score': dealScore,
    };
  }
}
