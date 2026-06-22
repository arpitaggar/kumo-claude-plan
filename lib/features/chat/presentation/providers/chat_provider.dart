import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../itinerary/presentation/providers/itinerary_provider.dart';
import '../../data/datasources/chat_remote_datasource.dart';
import '../../data/repositories/chat_repository_impl.dart';
import '../../domain/entities/message.dart';
import '../../domain/usecases/send_message_usecase.dart';

// ---------------------------------------------------------------------------
// Infrastructure providers
// ---------------------------------------------------------------------------

final chatRemoteDataSourceProvider = Provider<ChatRemoteDataSource>(
  (_) => const ChatRemoteDataSourceImpl(),
);

final chatRepositoryProvider = Provider<ChatRepositoryImpl>(
  (ref) => ChatRepositoryImpl(
    remoteDataSource: ref.watch(chatRemoteDataSourceProvider),
  ),
);

// ---------------------------------------------------------------------------
// Use-case providers
// ---------------------------------------------------------------------------

final sendMessageUseCaseProvider = Provider<SendMessageUseCase>(
  (ref) => SendMessageUseCase(ref.watch(chatRepositoryProvider)),
);

// ---------------------------------------------------------------------------
// Stream provider — live message list for one itinerary (last 100)
// ---------------------------------------------------------------------------

final chatStreamProvider =
    StreamProvider.family<List<Message>, String>((ref, itineraryId) =>
        ref.watch(chatRepositoryProvider).watchMessages(itineraryId).map(
              (either) => either.fold(
                (failure) => throw Exception(failure.message),
                (messages) => messages,
              ),
            ));

// ---------------------------------------------------------------------------
// Earlier-messages: direct repository access for REST pagination
// ---------------------------------------------------------------------------

final chatRepositoryRefProvider = Provider<ChatRepositoryImpl>(
  (ref) => ref.watch(chatRepositoryProvider),
);

// ---------------------------------------------------------------------------
// Inbox badge — tracks last visit time and whether there are unread messages
// ---------------------------------------------------------------------------

/// Epoch-ms timestamp of the last time the user opened the Inbox tab.
/// Initialised to 0; InboxPage updates it from SharedPreferences on mount.
final inboxLastVisitProvider = StateProvider<int>((_) => 0);

/// True when any trip has a message newer than [inboxLastVisitProvider].
final inboxHasUnreadProvider = Provider<bool>((ref) {
  final lastVisitMs = ref.watch(inboxLastVisitProvider);
  if (lastVisitMs == 0) {
    return false;
  }

  final listState = ref.watch(itineraryListProvider);
  if (listState is! ItineraryListLoaded) {
    return false;
  }

  for (final trip in listState.itineraries) {
    final msgs = ref.watch(chatStreamProvider(trip.id));
    final latest = msgs.value?.isNotEmpty == true ? msgs.value!.last : null;
    if (latest != null &&
        latest.createdAt.millisecondsSinceEpoch > lastVisitMs) {
      return true;
    }
  }
  return false;
});
