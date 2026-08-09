/// Flip to `true` once the Supabase Storage Image Transformation add-on is
/// enabled for this project (Supabase dashboard → Settings → Add-ons —
/// paid-tier only) — see docs/SCALABILITY_AUDIT.md SCALE-005.
///
/// Until then, this stays `false` so [resizedImageUrl] always returns the
/// original URL unchanged. Unlike `kIosPushReady`-style gates elsewhere in
/// this codebase (lib/core/notifications/push_config.dart), this one isn't
/// "will fail safely if flipped early" — the
/// render/image transform endpoint this feature depends on requires the
/// add-on to be active, and its behavior when it isn't (error vs.
/// serving the original) isn't something to assume without checking against
/// the actual project first. Leaving this `false` costs nothing (every
/// avatar/attachment already renders correctly today, just at full size);
/// flipping it on without confirming the add-on is enabled risks breaking
/// every image in the app at once.
const bool kImageResizingEnabled = false;

/// Rewrites a Supabase Storage *public object* URL to request a resized
/// variant via Supabase's image transformation endpoint, instead of always
/// downloading the full-size original — see docs/SCALABILITY_AUDIT.md
/// SCALE-005. A no-op (returns [url] unchanged) unless [kImageResizingEnabled]
/// is `true`.
///
/// When enabled: image transformation swaps the URL's `/object/public/` path
/// segment for `/render/image/public/` and adds width/height/quality query
/// params. Also returns [url] unchanged if it isn't a Supabase Storage
/// public object URL in the first place (e.g. `null`, or some other host).
String resizedImageUrl(
  String? url, {
  required int width,
  int? height,
  int quality = 75,
}) {
  if (url == null) {
    return '';
  }
  if (!kImageResizingEnabled) {
    return url;
  }
  return transformObjectUrl(
    url,
    width: width,
    height: height,
    quality: quality,
  );
}

/// The actual `/object/public/` -> `/render/image/public/` URL rewrite,
/// factored out from [resizedImageUrl] so it has real test coverage even
/// while [kImageResizingEnabled] is `false` and that path is otherwise
/// unreachable. Not meant to be called directly outside a test — go through
/// [resizedImageUrl], which respects the flag.
String transformObjectUrl(
  String url, {
  required int width,
  int? height,
  int quality = 75,
}) {
  const marker = '/storage/v1/object/public/';
  final markerIndex = url.indexOf(marker);
  if (markerIndex == -1) {
    return url;
  }

  final origin = url.substring(0, markerIndex);
  final bucketAndPath = url.substring(markerIndex + marker.length);

  final params = <String, String>{
    'width': '$width',
    if (height != null) 'height': '$height',
    'quality': '$quality',
    'resize': 'cover',
  };
  final query = params.entries.map((e) => '${e.key}=${e.value}').join('&');

  return '$origin/storage/v1/render/image/public/$bucketAndPath?$query';
}
