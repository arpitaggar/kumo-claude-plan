import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:uuid/uuid.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/network/supabase_client.dart';
import '../models/message_model.dart';

abstract class ChatRemoteDataSource {
  Stream<List<MessageModel>> watchMessages(String itineraryId);
  Future<void> sendMessage({
    required String itineraryId,
    required String senderId,
    required String senderName,
    required String content,
  });
}

class ChatRemoteDataSourceImpl implements ChatRemoteDataSource {
  const ChatRemoteDataSourceImpl();

  @override
  Stream<List<MessageModel>> watchMessages(String itineraryId) =>
      KumoSupabaseClient.client
          .from('messages')
          .stream(primaryKey: ['id'])
          .eq('itinerary_id', itineraryId)
          .order('created_at')
          .map((rows) => rows.map(MessageModel.fromJson).toList());

  @override
  Future<void> sendMessage({
    required String itineraryId,
    required String senderId,
    required String senderName,
    required String content,
  }) async {
    try {
      await KumoSupabaseClient.client.from('messages').insert({
        'id': const Uuid().v4(),
        'itinerary_id': itineraryId,
        'sender_id': senderId,
        'sender_name': senderName,
        'content': content,
      });
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }
}
