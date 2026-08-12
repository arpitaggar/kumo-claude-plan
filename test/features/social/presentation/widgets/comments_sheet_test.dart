import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/auth/domain/repositories/auth_repository.dart';
import 'package:kumo_claude/features/auth/domain/entities/user.dart';
import 'package:kumo_claude/features/auth/domain/usecases/delete_account_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/login_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/logout_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/signup_usecase.dart';
import 'package:kumo_claude/features/auth/presentation/providers/auth_provider.dart';
import 'package:kumo_claude/features/social/domain/entities/post_comment.dart';
import 'package:kumo_claude/features/social/domain/repositories/social_repository.dart';
import 'package:kumo_claude/features/social/presentation/providers/social_provider.dart';
import 'package:kumo_claude/features/social/presentation/widgets/comments_sheet.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_helpers.dart';

class MockSocialRepository extends Mock implements SocialRepository {}

class MockAuthRepository extends Mock implements AuthRepository {}

class MockLoginUseCase extends Mock implements LoginUseCase {}

class MockSignupUseCase extends Mock implements SignupUseCase {}

class MockLogoutUseCase extends Mock implements LogoutUseCase {}

class MockDeleteAccountUseCase extends Mock implements DeleteAccountUseCase {}

/// Same fixture pattern as social_provider_test.dart's `_buildAuthNotifier`.
AuthNotifier _buildAuthNotifier(User user) {
  final repo = MockAuthRepository();
  when(repo.getCurrentUser).thenAnswer((_) async => Right(user));
  return AuthNotifier(
    loginUseCase: MockLoginUseCase(),
    signupUseCase: MockSignupUseCase(),
    logoutUseCase: MockLogoutUseCase(),
    deleteAccountUseCase: MockDeleteAccountUseCase(),
    repository: repo,
  );
}

final _user = User(
  id: 'user-1',
  email: 'me@example.com',
  createdAt: DateTime(2026),
);

void main() {
  setUpAll(initTestSupabase);

  late MockSocialRepository mockRepo;

  setUp(() {
    mockRepo = MockSocialRepository();
  });

  Future<void> pumpSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          socialRepositoryProvider.overrideWithValue(mockRepo),
          authNotifierProvider.overrideWith((ref) => _buildAuthNotifier(_user)),
        ],
        child: MaterialApp(
          home: Scaffold(body: CommentsSheet(postId: 'post-1')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('shows a comment from the stream', (tester) async {
    when(() => mockRepo.watchComments('post-1')).thenAnswer(
      (_) => Stream.value(
        Right([
          PostComment(
            id: 'comment-1',
            postId: 'post-1',
            authorId: 'user-2',
            authorName: 'Bob',
            content: 'What a great trip!',
            createdAt: DateTime.utc(2026, 6, 1),
          ),
        ]),
      ),
    );

    await pumpSheet(tester);

    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('What a great trip!'), findsOneWidget);
  });

  testWidgets('shows the empty state when there are no comments', (
    tester,
  ) async {
    when(
      () => mockRepo.watchComments('post-1'),
    ).thenAnswer((_) => Stream.value(const Right([])));

    await pumpSheet(tester);

    expect(find.text('No comments yet — be the first!'), findsOneWidget);
  });

  testWidgets('shows a delete affordance only on the current user\'s own '
      'comment', (tester) async {
    when(() => mockRepo.watchComments('post-1')).thenAnswer(
      (_) => Stream.value(
        Right([
          PostComment(
            id: 'comment-mine',
            postId: 'post-1',
            authorId: 'user-1',
            authorName: 'Me',
            content: 'My comment',
            createdAt: DateTime.utc(2026, 6, 1),
          ),
          PostComment(
            id: 'comment-other',
            postId: 'post-1',
            authorId: 'user-2',
            authorName: 'Bob',
            content: 'Their comment',
            createdAt: DateTime.utc(2026, 6, 2),
          ),
        ]),
      ),
    );

    await pumpSheet(tester);

    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });

  testWidgets('sends a comment and clears the input field', (tester) async {
    when(
      () => mockRepo.watchComments('post-1'),
    ).thenAnswer((_) => Stream.value(const Right([])));
    when(
      () => mockRepo.addComment(
        postId: any(named: 'postId'),
        authorId: any(named: 'authorId'),
        authorName: any(named: 'authorName'),
        content: any(named: 'content'),
        authorAvatarUrl: any(named: 'authorAvatarUrl'),
      ),
    ).thenAnswer((_) async => const Right(null));

    await pumpSheet(tester);

    await tester.enterText(find.byType(TextField), 'Nice!');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    await tester.pump();

    verify(
      () => mockRepo.addComment(
        postId: 'post-1',
        authorId: 'user-1',
        authorName: any(named: 'authorName'),
        content: 'Nice!',
        authorAvatarUrl: any(named: 'authorAvatarUrl'),
      ),
    ).called(1);
  });
}
