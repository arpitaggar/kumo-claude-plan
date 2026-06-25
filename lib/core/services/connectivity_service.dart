import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConnectivityService {
  static final _connectivity = Connectivity();

  /// Emits `true` when any connection type is available, `false` when none.
  static Stream<bool> get onConnectivityChanged => _connectivity
      .onConnectivityChanged
      .map((results) => results.any((r) => r != ConnectivityResult.none));

  static Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }
}

/// Streams `true`/`false` as network status changes.
final connectivityStreamProvider = StreamProvider<bool>(
  (_) => ConnectivityService.onConnectivityChanged,
);

/// Synchronous bool derived from [connectivityStreamProvider].
/// Defaults to `true` while the stream initialises (optimistic).
final isOnlineProvider = Provider<bool>(
  (ref) => ref.watch(connectivityStreamProvider).maybeWhen(
        data: (online) => online,
        orElse: () => true,
      ),
);
