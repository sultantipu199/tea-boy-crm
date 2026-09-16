class AiAnalysis {
  final String sentiment;
  final bool isWrongContact;
  final String painPoints;
  final String recommendedAction;
  final String followUpMessage;
  final String nextFollowUpDate;
  final int dealScore;

  AiAnalysis({
    required this.sentiment,
    this.isWrongContact = false,
    required this.painPoints,
    required this.recommendedAction,
    required this.followUpMessage,
    required this.nextFollowUpDate,
    required this.dealScore,
  });

  factory AiAnalysis.fromJson(Map<dynamic, dynamic> json) {
    // Robust pain_points extraction (accepts either string or list of strings)
    String extractPainPoints(dynamic raw) {
      if (raw == null) return '';
      if (raw is String) return raw;
      if (raw is List) {
        return raw.map((e) => e.toString()).join('\n• ');
      }
      return raw.toString();
    }

    final rawIsWrongContact = json['is_wrong_contact'];
    final bool parsedIsWrong = rawIsWrongContact is bool
        ? rawIsWrongContact
        : (rawIsWrongContact?.toString().toLowerCase() == 'true');

    final rawSentiment = json['sentiment']?.toString() ?? 'Interested';

    return AiAnalysis(
      sentiment: rawSentiment,
      isWrongContact: parsedIsWrong || rawSentiment.toLowerCase().contains('wrong contact'),
      painPoints: extractPainPoints(json['pain_points']),
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
      'is_wrong_contact': isWrongContact,
      'pain_points': painPoints,
      'recommended_action': recommendedAction,
      'follow_up_message': followUpMessage,
      'next_follow_up_date': nextFollowUpDate,
      'deal_score': dealScore,
    };
  }

  AiAnalysis copyWith({
    String? sentiment,
    bool? isWrongContact,
    String? painPoints,
    String? recommendedAction,
    String? followUpMessage,
    String? nextFollowUpDate,
    int? dealScore,
  }) {
    return AiAnalysis(
      sentiment: sentiment ?? this.sentiment,
      isWrongContact: isWrongContact ?? this.isWrongContact,
      painPoints: painPoints ?? this.painPoints,
      recommendedAction: recommendedAction ?? this.recommendedAction,
      followUpMessage: followUpMessage ?? this.followUpMessage,
      nextFollowUpDate: nextFollowUpDate ?? this.nextFollowUpDate,
      dealScore: dealScore ?? this.dealScore,
    );
  }
}
