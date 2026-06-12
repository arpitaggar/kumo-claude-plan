import '../../domain/entities/travel_itinerary.dart';

/// Data model for [TravelItinerary] with JSON serialization.
class ItineraryModel extends TravelItinerary {
  const ItineraryModel({
    required super.id,
    required super.title,
    required super.ownerId,
    required super.startDate,
    required super.endDate,
    required super.totalBudget,
    required super.currencyCode,
    required super.members,
    required super.items,
    required super.expenseSummary,
    required super.createdAt,
    required super.updatedAt,
    super.description,
    super.status,
  });

  factory ItineraryModel.fromJson(Map<String, dynamic> json) => ItineraryModel(
    id: json['id'] as String,
    title: json['title'] as String,
    ownerId: json['owner_id'] as String,
    startDate: DateTime.parse(json['start_date'] as String),
    endDate: DateTime.parse(json['end_date'] as String),
    totalBudget: (json['total_budget'] as num).toDouble(),
    currencyCode: json['currency_code'] as String,
    members: (json['members'] as List<dynamic>)
        .map((m) => GroupMemberModel.fromJson(m as Map<String, dynamic>))
        .toList(),
    items: (json['items'] as List<dynamic>)
        .map((i) => ItineraryItemModel.fromJson(i as Map<String, dynamic>))
        .toList(),
    expenseSummary: ExpenseSummaryModel.fromJson(
      json['expense_summary'] as Map<String, dynamic>? ??
          const {'total_spent': 0, 'spent_by_category': {}, 'member_balances': {}},
    ),
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
    description: json['description'] as String?,
    status: ItineraryStatusEnum.values.firstWhere(
      (s) => s.name == (json['status'] as String? ?? 'draft'),
      orElse: () => ItineraryStatusEnum.draft,
    ),
  );

  factory ItineraryModel.fromEntity(TravelItinerary e) => ItineraryModel(
    id: e.id,
    title: e.title,
    ownerId: e.ownerId,
    startDate: e.startDate,
    endDate: e.endDate,
    totalBudget: e.totalBudget,
    currencyCode: e.currencyCode,
    members: e.members,
    items: e.items,
    expenseSummary: e.expenseSummary,
    createdAt: e.createdAt,
    updatedAt: e.updatedAt,
    description: e.description,
    status: e.status,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'owner_id': ownerId,
    'start_date': startDate.toIso8601String(),
    'end_date': endDate.toIso8601String(),
    'total_budget': totalBudget,
    'currency_code': currencyCode,
    'members': members
        .map((m) => GroupMemberModel.fromEntity(m).toJson())
        .toList(),
    'items': items
        .map((i) => ItineraryItemModel.fromEntity(i).toJson())
        .toList(),
    'expense_summary': ExpenseSummaryModel.fromEntity(expenseSummary).toJson(),
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'description': description,
    'status': status.name,
  };
}

class GroupMemberModel extends GroupMember {
  const GroupMemberModel({
    required super.userId,
    required super.userName,
    required super.role,
    required super.joinedAt,
  });

  factory GroupMemberModel.fromJson(Map<String, dynamic> json) =>
      GroupMemberModel(
        userId: json['user_id'] as String,
        userName: json['user_name'] as String,
        role: GroupMemberRole.values.firstWhere(
          (r) => r.name == (json['role'] as String),
          orElse: () => GroupMemberRole.viewer,
        ),
        joinedAt: DateTime.parse(json['joined_at'] as String),
      );

  factory GroupMemberModel.fromEntity(GroupMember e) => GroupMemberModel(
    userId: e.userId,
    userName: e.userName,
    role: e.role,
    joinedAt: e.joinedAt,
  );

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'user_name': userName,
    'role': role.name,
    'joined_at': joinedAt.toIso8601String(),
  };
}

class ItineraryItemModel extends ItineraryItem {
  const ItineraryItemModel({
    required super.id,
    required super.itemType,
    required super.title,
    required super.startTime,
    super.endTime,
    super.location,
    super.latitude,
    super.longitude,
  });

  factory ItineraryItemModel.fromJson(Map<String, dynamic> json) =>
      ItineraryItemModel(
        id: json['id'] as String,
        itemType: json['item_type'] as String,
        title: json['title'] as String,
        startTime: DateTime.parse(json['start_time'] as String),
        endTime: json['end_time'] != null
            ? DateTime.parse(json['end_time'] as String)
            : null,
        location: json['location'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
      );

  factory ItineraryItemModel.fromEntity(ItineraryItem e) =>
      ItineraryItemModel(
        id: e.id,
        itemType: e.itemType,
        title: e.title,
        startTime: e.startTime,
        endTime: e.endTime,
        location: e.location,
        latitude: e.latitude,
        longitude: e.longitude,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'item_type': itemType,
    'title': title,
    'start_time': startTime.toIso8601String(),
    'end_time': endTime?.toIso8601String(),
    'location': location,
    'latitude': latitude,
    'longitude': longitude,
  };
}

class ExpenseSummaryModel extends ExpenseSummary {
  const ExpenseSummaryModel({
    required super.totalSpent,
    required super.spentByCategory,
    required super.memberBalances,
  });

  factory ExpenseSummaryModel.fromJson(Map<String, dynamic> json) =>
      ExpenseSummaryModel(
        totalSpent: (json['total_spent'] as num).toDouble(),
        spentByCategory: Map<String, double>.from(
          (json['spent_by_category'] as Map<String, dynamic>).map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          ),
        ),
        memberBalances: Map<String, double>.from(
          (json['member_balances'] as Map<String, dynamic>).map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          ),
        ),
      );

  factory ExpenseSummaryModel.fromEntity(ExpenseSummary e) =>
      ExpenseSummaryModel(
        totalSpent: e.totalSpent,
        spentByCategory: e.spentByCategory,
        memberBalances: e.memberBalances,
      );

  Map<String, dynamic> toJson() => {
    'total_spent': totalSpent,
    'spent_by_category': spentByCategory,
    'member_balances': memberBalances,
  };
}
