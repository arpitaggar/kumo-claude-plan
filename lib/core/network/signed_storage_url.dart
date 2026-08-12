import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'supabase_client.dart';

/// The path marker Supabase Storage embeds in a "public object" URL, as
/// produced by `StorageFileApi.getPublicUrl()`. Also used by
/// `supabase_image_url.dart`'s `transformObjectUrl` for the (currently
/// disabled) image-resizing path.
const _publicObjectMarker = '/storage/v1/object/public/';

/// Splits a Supabase Storage "public object" URL (of the shape
/// `.../storage/v1/object/public/{bucket}/{path...}[?query]`) into its
/// bucket and path.
///
/// `avatars` and `chat-attachments` are private buckets as of
/// `stage43_private_avatars_chat_attachments.sql` — `getPublicUrl()` is pure
/// string construction (no network call, no bucket-existence check), so it
/// still returns this URL shape purely as a `{bucket}/{path}` encoding.
/// Callers must exchange it for a real signed URL via
/// [signedStorageUrlProvider] before rendering; the raw value returned by
/// `getPublicUrl()` no longer resolves directly.
///
/// Returns null if [url] isn't recognized as this URL shape.
({String bucket, String path})? parseStorageObjectUrl(String url) {
  final markerIndex = url.indexOf(_publicObjectMarker);
  if (markerIndex == -1) {
    return null;
  }
  final rest = url.substring(markerIndex + _publicObjectMarker.length);
  final queryIndex = rest.indexOf('?');
  final bucketAndPath = queryIndex == -1 ? rest : rest.substring(0, queryIndex);
  final slashIndex = bucketAndPath.indexOf('/');
  if (slashIndex == -1) {
    return null;
  }
  return (
    bucket: bucketAndPath.substring(0, slashIndex),
    path: bucketAndPath.substring(slashIndex + 1),
  );
}

/// Signed-URL lifetime. Long enough that a typical session never needs a
/// refresh; if it does expire, the image just fails to load until this
/// provider is re-watched (e.g. re-entering the screen) — no active refresh
/// loop, matching this codebase's general preference for the simplest
/// mechanism that covers the real usage pattern.
const _signedUrlTtl = Duration(hours: 6);

/// Resolves a stored Supabase Storage object URL (see
/// [parseStorageObjectUrl]) — e.g. `UserProfile.avatarUrl`,
/// `MessageAttachment.url` — to a time-limited signed URL, required to
/// render anything from the private `avatars`/`chat-attachments` buckets.
///
/// Cached per [sourceUrl] for the provider's lifetime (Riverpod's default
/// `.family` behavior — no `.autoDispose`, so repeat widget rebuilds and
/// re-renders of the same avatar/attachment across the app reuse one signed
/// URL instead of re-signing on every build).
///
/// Returns null (renders as "no image", same as a null source URL) if
/// [sourceUrl] isn't a recognized Storage object URL or signing fails —
/// e.g. the caller lost access (removed from the trip, profile went
/// private) since the URL was first stored.
final signedStorageUrlProvider = FutureProvider.family<String?, String>((
  ref,
  sourceUrl,
) async {
  final parsed = parseStorageObjectUrl(sourceUrl);
  if (parsed == null) {
    return null;
  }
  try {
    return await KumoSupabaseClient.client.storage
        .from(parsed.bucket)
        .createSignedUrl(parsed.path, _signedUrlTtl.inSeconds);
  } catch (_) {
    return null;
  }
});
