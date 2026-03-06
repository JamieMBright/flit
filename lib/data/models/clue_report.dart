/// A player-submitted report about incorrect clue data (flags, outlines, etc.).
class ClueReport {
  const ClueReport({
    required this.id,
    required this.reporterId,
    required this.countryCode,
    required this.countryName,
    required this.issue,
    this.notes,
    this.status = 'pending',
    this.reviewedBy,
    this.reviewedAt,
    this.actionTaken,
    this.createdAt,
    this.reporterUsername,
  });

  final int id;
  final String reporterId;
  final String countryCode;
  final String countryName;

  /// One of: 'Flag is incorrect', 'Outline is wrong', 'Capital is incorrect',
  /// 'Border countries are wrong', 'Stats are inaccurate', 'Other'.
  final String issue;
  final String? notes;

  /// One of: 'pending', 'reviewed', 'actioned', 'dismissed'.
  final String status;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? actionTaken;
  final DateTime? createdAt;

  /// Denormalized from a join — not stored on the report itself.
  final String? reporterUsername;

  bool get isPending => status == 'pending';

  factory ClueReport.fromJson(Map<String, dynamic> json) => ClueReport(
        id: json['id'] as int,
        reporterId: json['reporter_id'] as String,
        countryCode: json['country_code'] as String,
        countryName: json['country_name'] as String,
        issue: json['issue'] as String,
        notes: json['notes'] as String?,
        status: json['status'] as String? ?? 'pending',
        reviewedBy: json['reviewed_by'] as String?,
        reviewedAt: json['reviewed_at'] != null
            ? DateTime.tryParse(json['reviewed_at'] as String)
            : null,
        actionTaken: json['action_taken'] as String?,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
        reporterUsername: json['reporter_username'] as String?,
      );

  Map<String, dynamic> toInsertJson() => {
        'reporter_id': reporterId,
        'country_code': countryCode,
        'country_name': countryName,
        'issue': issue,
        if (notes != null) 'notes': notes,
      };
}

/// Predefined clue issue types.
abstract final class ClueIssueType {
  static const flagIncorrect = 'Flag is incorrect';
  static const outlineWrong = 'Outline is wrong';
  static const capitalIncorrect = 'Capital is incorrect';
  static const borderCountriesWrong = 'Border countries are wrong';
  static const statsInaccurate = 'Stats are inaccurate';
  static const other = 'Other';

  static const all = [
    flagIncorrect,
    outlineWrong,
    capitalIncorrect,
    borderCountriesWrong,
    statsInaccurate,
    other,
  ];
}
