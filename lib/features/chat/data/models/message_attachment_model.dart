import '../../domain/entities/message_attachment.dart';

class MessageAttachmentModel extends MessageAttachment {
  const MessageAttachmentModel({
    required super.id,
    required super.kind,
    required super.url,
    required super.fileName,
    required super.mimeType,
    required super.sizeBytes,
  });

  factory MessageAttachmentModel.fromJson(Map<String, dynamic> json) =>
      MessageAttachmentModel(
        id: json['id'] as String,
        kind: json['kind'] as String,
        url: json['public_url'] as String,
        fileName: json['file_name'] as String,
        mimeType: json['mime_type'] as String,
        sizeBytes: (json['size_bytes'] as num).toInt(),
      );
}
