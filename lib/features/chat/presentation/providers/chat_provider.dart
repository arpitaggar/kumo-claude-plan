import 'package:flutter_riverpod/flutter_riverpod.dart';

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
// Stream provider — live message list for one itinerary
// ---------------------------------------------------------------------------

final chatStreamProvider =
    StreamProvider.family<List<Message>, String>((ref, itineraryId) =>
        ref.watch(chatRepositoryProvider).watchMessages(itineraryId).map(
              (either) => either.fold(
                (failure) => throw Exception(failure.message),
                (messages) => messages,
              ),
            ));
