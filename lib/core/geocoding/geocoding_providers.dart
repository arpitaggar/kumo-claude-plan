import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'geocoding_service.dart';
import 'nominatim_geocoding_service.dart';

final geocodingServiceProvider = Provider<GeocodingService>(
  (_) => NominatimGeocodingService(),
);
