import 'package:equatable/equatable.dart';

/// A company/workspace whose trips can be tagged (`TravelItinerary.orgId`)
/// so an org admin gets narrow oversight of them — see stage28's migration.
class Organization extends Equatable {
  const Organization({
    required this.id,
    required this.name,
    required this.slug,
    required this.ownerId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String slug;
  final String ownerId;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  List<Object?> get props => [id, name, slug, ownerId, createdAt, updatedAt];
}
