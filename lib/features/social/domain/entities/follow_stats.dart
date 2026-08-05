import 'package:equatable/equatable.dart';

/// Follow-graph counts for a single profile, from the current viewer's
/// perspective.
class FollowStats extends Equatable {
  const FollowStats({
    required this.followerCount,
    required this.followingCount,
    required this.isFollowedByMe,
  });

  final int followerCount;
  final int followingCount;
  final bool isFollowedByMe;

  FollowStats copyWith({int? followerCount, bool? isFollowedByMe}) =>
      FollowStats(
        followerCount: followerCount ?? this.followerCount,
        followingCount: followingCount,
        isFollowedByMe: isFollowedByMe ?? this.isFollowedByMe,
      );

  @override
  List<Object> get props => [followerCount, followingCount, isFollowedByMe];
}
