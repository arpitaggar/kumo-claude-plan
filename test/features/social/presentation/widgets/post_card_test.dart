import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/social/domain/entities/itinerary_post.dart';
import 'package:kumo_claude/features/social/presentation/widgets/post_card.dart';

void main() {
  final tPost = ItineraryPost(
    id: 'post-1',
    authorId: 'user-1',
    authorName: 'Alice',
    title: 'Tokyo Summer 2026',
    description: 'A week exploring Tokyo',
    startDate: DateTime.utc(2026, 6),
    endDate: DateTime.utc(2026, 6, 7),
    themeKey: 'classic',
    currencyCode: 'JPY',
    items: const [],
    segments: const [],
    likeCount: 3,
    likedByMe: false,
    createdAt: DateTime.utc(2026, 6, 10),
  );

  Widget buildCard({
    ItineraryPost? post,
    VoidCallback? onAuthorTap,
    VoidCallback? onLike,
    VoidCallback? onFork,
  }) => MaterialApp(
    home: Scaffold(
      body: PostCard(
        post: post ?? tPost,
        onAuthorTap: onAuthorTap ?? () {},
        onLike: onLike ?? () {},
        onFork: onFork ?? () {},
      ),
    ),
  );

  testWidgets('shows the title, author name, and like count', (tester) async {
    await tester.pumpWidget(buildCard());

    expect(find.text('Tokyo Summer 2026'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('shows the description when present', (tester) async {
    await tester.pumpWidget(buildCard());
    expect(find.text('A week exploring Tokyo'), findsOneWidget);
  });

  testWidgets('does not show a "Remixed" chip when forkedFromPostId is null', (
    tester,
  ) async {
    await tester.pumpWidget(buildCard());
    expect(find.text('Remixed'), findsNothing);
  });

  testWidgets('shows a "Remixed" chip when forkedFromPostId is set', (
    tester,
  ) async {
    final forked = ItineraryPost(
      id: tPost.id,
      authorId: tPost.authorId,
      authorName: tPost.authorName,
      title: tPost.title,
      startDate: tPost.startDate,
      endDate: tPost.endDate,
      themeKey: tPost.themeKey,
      currencyCode: tPost.currencyCode,
      items: tPost.items,
      segments: tPost.segments,
      likeCount: tPost.likeCount,
      likedByMe: tPost.likedByMe,
      createdAt: tPost.createdAt,
      forkedFromPostId: 'post-0',
    );

    await tester.pumpWidget(buildCard(post: forked));
    expect(find.text('Remixed'), findsOneWidget);
  });

  testWidgets('fires onAuthorTap when the author row is tapped', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(buildCard(onAuthorTap: () => tapped = true));

    await tester.tap(find.text('Alice'));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('fires onLike when the like control is tapped', (tester) async {
    var tapped = false;
    await tester.pumpWidget(buildCard(onLike: () => tapped = true));

    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('shows a filled heart when likedByMe is true', (tester) async {
    final liked = ItineraryPost(
      id: tPost.id,
      authorId: tPost.authorId,
      authorName: tPost.authorName,
      title: tPost.title,
      startDate: tPost.startDate,
      endDate: tPost.endDate,
      themeKey: tPost.themeKey,
      currencyCode: tPost.currencyCode,
      items: tPost.items,
      segments: tPost.segments,
      likeCount: tPost.likeCount,
      likedByMe: true,
      createdAt: tPost.createdAt,
    );

    await tester.pumpWidget(buildCard(post: liked));
    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsNothing);
  });

  testWidgets('fires onFork when "Use this itinerary" is tapped', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(buildCard(onFork: () => tapped = true));

    await tester.tap(find.text('Use this itinerary'));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
