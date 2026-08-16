import 'dart:async';

/// Which kind of screen a notification tap should open.
enum NotificationTapKind { chat, social, dm }

/// A user tapped a notification — decoupled from *how* it was shown
/// (`flutter_local_notifications`' tap callback, or iOS's FCM open-app
/// event) and from *where* it navigates to.
class NotificationTapEvent {
  const NotificationTapEvent({required this.kind, required this.id});

  final NotificationTapKind kind;

  /// `tripId` for [NotificationTapKind.chat], `actorId` for
  /// [NotificationTapKind.social], `conversationId` for
  /// [NotificationTapKind.dm].
  final String id;
}

final _tapController = StreamController<NotificationTapEvent>.broadcast();

/// `core/notifications` previously imported `config/router.dart` directly
/// from both `notification_service.dart` and `push_message_handler.dart` —
/// a low-level plugin wrapper depending on a high-level navigation policy
/// module, and the same tap→route decision duplicated in both places. Both
/// now just emit onto this stream; exactly one subscriber (`main.dart`,
/// which already owns `config/router.dart`) turns an event into an actual
/// `GoRouter` navigation, in one place.
Stream<NotificationTapEvent> get notificationTaps => _tapController.stream;

void emitNotificationTap(NotificationTapEvent event) =>
    _tapController.add(event);
