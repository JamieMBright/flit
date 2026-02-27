/// A player-submitted report for moderation review.
class PlayerReport {
  const PlayerReport({
    required this.id,
    required this.reporterId,
    required this.reportedId,
    required this.reason,
    this.details,
    this.status = 'pending',
    this.reviewedBy,
    this.reviewedAt,
    this.actionTaken,
    this.createdAt,
    this.reportedUsername,
    this.reporterUsername,
  });

  final int id;
  final String reporterId;
  final String reportedId;

  /// One of: 'offensive_username', 'cheating', 'harassment', 'other'.
  final String reason;
  final String? details;

  /// One of: 'pending', 'reviewed', 'actioned', 'dismissed'.
  final String status;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? actionTaken;
  final DateTime? createdAt;

  /// Denormalized from a join — not stored on the report itself.
  final String? reportedUsername;
  final String? reporterUsername;

  bool get isPending => status == 'pending';

  factory PlayerReport.fromJson(Map<String, dynamic> json) => PlayerReport(
    id: json['id'] as int,
    reporterId: json['reporter_id'] as String,
    reportedId: json['reported_id'] as String,
    reason: json['reason'] as String,
    details: json['details'] as String?,
    status: json['status'] as String? ?? 'pending',
    reviewedBy: json['reviewed_by'] as String?,
    reviewedAt: json['reviewed_at'] != null
        ? DateTime.tryParse(json['reviewed_at'] as String)
        : null,
    actionTaken: json['action_taken'] as String?,
    createdAt: json['created_at'] != null
        ? DateTime.tryParse(json['created_at'] as String)
        : null,
    reportedUsername: json['reported_username'] as String?,
    reporterUsername: json['reporter_username'] as String?,
  );

  Map<String, dynamic> toInsertJson() => {
    'reporter_id': reporterId,
    'reported_id': reportedId,
    'reason': reason,
    if (details != null) 'details': details,
  };
}

/// Predefined report reasons.
abstract final class ReportReason {
  static const offensiveUsername = 'offensive_username';
  static const cheating = 'cheating';
  static const harassment = 'harassment';
  static const other = 'other';

  static const all = [offensiveUsername, cheating, harassment, other];

  static String label(String reason) {
    switch (reason) {
      case offensiveUsername:
        return 'Offensive Username';
      case cheating:
        return 'Cheating';
      case harassment:
        return 'Harassment';
      case other:
        return 'Other';
      default:
        return reason;
    }
  }
}
