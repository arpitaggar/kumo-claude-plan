import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/profile_remote_datasource.dart';
import '../../data/repositories/profile_lookup_repository_impl.dart';
import '../../domain/repositories/profile_lookup_repository.dart';
import '../../domain/usecases/create_pending_invitation_usecase.dart';
import '../../domain/usecases/find_profile_by_email_usecase.dart';
import '../../domain/usecases/get_current_user_profile_result_usecase.dart';
import '../../domain/usecases/search_profiles_by_name_usecase.dart';
import '../../domain/usecases/update_searchability_usecase.dart';

// Shared between InviteMemberPage (itinerary feature) and PrivacySettingsPage
// (settings feature) — previously each page defined its own page-local
// `_profileDataSourceProvider` and called `ProfileRemoteDataSource` directly,
// with no domain layer above it at all.

// ---------------------------------------------------------------------------
// Infrastructure
// ---------------------------------------------------------------------------

final profileRemoteDataSourceProvider = Provider<ProfileRemoteDataSource>(
  (_) => const ProfileRemoteDataSourceImpl(),
);

final profileLookupRepositoryProvider = Provider<ProfileLookupRepository>(
  (ref) =>
      ProfileLookupRepositoryImpl(ref.watch(profileRemoteDataSourceProvider)),
);

// ---------------------------------------------------------------------------
// Use-case providers
// ---------------------------------------------------------------------------

final findProfileByEmailUseCaseProvider = Provider<FindProfileByEmailUseCase>(
  (ref) =>
      FindProfileByEmailUseCase(ref.watch(profileLookupRepositoryProvider)),
);

final searchProfilesByNameUseCaseProvider =
    Provider<SearchProfilesByNameUseCase>(
      (ref) => SearchProfilesByNameUseCase(
        ref.watch(profileLookupRepositoryProvider),
      ),
    );

final updateSearchabilityUseCaseProvider = Provider<UpdateSearchabilityUseCase>(
  (ref) =>
      UpdateSearchabilityUseCase(ref.watch(profileLookupRepositoryProvider)),
);

final getCurrentUserProfileResultUseCaseProvider =
    Provider<GetCurrentUserProfileResultUseCase>(
      (ref) => GetCurrentUserProfileResultUseCase(
        ref.watch(profileLookupRepositoryProvider),
      ),
    );

final createPendingInvitationUseCaseProvider =
    Provider<CreatePendingInvitationUseCase>(
      (ref) => CreatePendingInvitationUseCase(
        ref.watch(profileLookupRepositoryProvider),
      ),
    );
