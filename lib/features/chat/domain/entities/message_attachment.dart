import 'package:equatable/equatable.dart';

/// Kind of file attached to a message — drives which bubble renderer is used.
class AttachmentKind {
  static const image = 'image';
  static const file = 'file';
}

class MessageAttachment extends Equatable {
  const MessageAttachment({
    required this.id,
    required this.kind,
    required this.url,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
  });

  final String id;

  /// [AttachmentKind.image] or [AttachmentKind.file].
  final String kind;
  final String url;
  final String fileName;
  final String mimeType;
  final int sizeBytes;

  bool get isImage => kind == AttachmentKind.image;

  @override
  List<Object> get props => [id, kind, url, fileName, mimeType, sizeBytes];
}
