import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/signed_storage_url.dart';

/// Drop-in replacement for `CircleAvatar(backgroundImage: NetworkImage(url))`
/// that resolves [sourceUrl] to a signed URL first — the `avatars` bucket is
/// private (see `stage43_private_avatars_chat_attachments.sql`), so the raw
/// stored URL doesn't resolve directly.
///
/// Shows [fallback] whenever there's no image to show yet: [sourceUrl] is
/// null/empty, the signed URL is still resolving, or resolution failed
/// (e.g. the viewer no longer has access because the profile went private).
class KumoAvatar extends ConsumerWidget {
  const KumoAvatar({
    required this.sourceUrl,
    required this.radius,
    super.key,
    this.backgroundColor,
    this.fallback,
  });

  final String? sourceUrl;
  final double radius;
  final Color? backgroundColor;
  final Widget? fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = sourceUrl;
    if (url == null || url.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor,
        child: fallback,
      );
    }

    final resolved = ref.watch(signedStorageUrlProvider(url)).valueOrNull;
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      backgroundImage: resolved != null ? NetworkImage(resolved) : null,
      child: resolved == null ? fallback : null,
    );
  }
}
