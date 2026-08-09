import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/profile/presentation/providers/user_profile_provider.dart';
import 'geocoding_service.dart';
import 'nominatim_geocoding_service.dart';

/// Prefers the user's explicit `preferredLanguage` profile setting (ISO
/// 639-1), then the device locale, then English — so geocoding results
/// come back in one consistent language rather than each place's own local
/// script.
final geocodingServiceProvider = Provider<GeocodingService>((ref) {
  final preferredLanguage = ref
      .watch(userProfileProvider)
      .valueOrNull
      ?.preferredLanguage;
  final languageCode = preferredLanguage?.isNotEmpty == true
      ? preferredLanguage
      : PlatformDispatcher.instance.locale.languageCode;
  return NominatimGeocodingService(acceptLanguage: languageCode);
});
