/// A system announcement displayed to all players.
class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    this.type = 'info',
    this.priority = 0,
    this.isActive = true,
    this.startsAt,
    this.expiresAt,
    this.createdBy,
    this.createdAt,
  });

  final int id;
  final String title;
  final String body;

  /// One of: 'info', 'warning', 'event', 'maintenance'.
  final String type;
  final int priority;
  final bool isActive;
  final DateTime? startsAt;
  final DateTime? expiresAt;
  final String? createdBy;
  final DateTime? createdAt;

  factory Announcement.fromJson(Map<String, dynamic> json) => Announcement(
    id: json['id'] as int,
    title: json['title'] as String,
    body: json['body'] as String,
    type: json['type'] as String? ?? 'info',
    priority: json['priority'] as int? ?? 0,
    isActive: json['is_active'] as bool? ?? true,
    startsAt: json['starts_at'] != null
        ? DateTime.tryParse(json['starts_at'] as String)
        : null,
    expiresAt: json['expires_at'] != null
        ? DateTime.tryParse(json['expires_at'] as String)
        : null,
    createdBy: json['created_by'] as String?,
    createdAt: json['created_at'] != null
        ? DateTime.tryParse(json['created_at'] as String)
        : null,
  );
}
