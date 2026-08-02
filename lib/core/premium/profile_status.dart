import 'package:equatable/equatable.dart';

/// One row from `public.profile_status` — an append-only history log of
/// premium grants/expirations (signup trial, goodwill extension, paid
/// subscription, ...), mirroring the existing username_history /
/// profile_change_log audit-trail pattern rather than overwriting a single
/// mutable column. "Is the user premium now" is always the single most
/// recent row for that user, checked against [expiresAt].
class ProfileStatus extends Equatable {
  const ProfileStatus({
    required this.id,
    required this.userId,
    required this.status,
    required this.reason,
    required this.createdAt,
    this.expiresAt,
  });

  factory ProfileStatus.fromJson(Map<String, dynamic> json) => ProfileStatus(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        status: json['status'] as String,
        reason: json['reason'] as String,
        expiresAt: json['expires_at'] != null
            ? DateTime.parse(json['expires_at'] as String).toUtc()
            : null,
        createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
      );

  final String id;
  final String userId;

  /// 'premium' or 'normal'.
  final String status;

  /// Human-readable audit note, e.g. "14-day trial on signup",
  /// "14-day trial on signup — ended", "goodwill: refund good faith credit".
  final String reason;

  /// Only meaningful when [status] is 'premium'. Null means indefinite
  /// (e.g. an active paid subscription).
  final DateTime? expiresAt;

  final DateTime createdAt;

  bool get isCurrentlyPremium =>
      status == 'premium' &&
      (expiresAt == null || expiresAt!.isAfter(DateTime.now()));

  @override
  List<Object?> get props => [id, userId, status, reason, expiresAt, createdAt];
}
