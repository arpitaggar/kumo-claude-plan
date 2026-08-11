import '../../domain/entities/xp_event.dart';

class XpEventModel extends XpEvent {
  const XpEventModel({
    required super.id,
    required super.userId,
    required super.amount,
    required super.reason,
    required super.sourceType,
    required super.sourceId,
    required super.createdAt,
  });

  factory XpEventModel.fromJson(Map<String, dynamic> json) => XpEventModel(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    amount: json['amount'] as int,
    reason: json['reason'] as String,
    sourceType: json['source_type'] as String,
    sourceId: json['source_id'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}
