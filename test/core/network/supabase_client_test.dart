import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/network/supabase_client.dart';

void main() {
  group('KumoSupabaseClient.initialize', () {
    test('fails fast with a clear StateError instead of hanging when '
        'SUPABASE_URL/SUPABASE_ANON_KEY are unset', () async {
      // `flutter test` runs with no --dart-define, so
      // Environment.supabaseUrl/supabaseAnonKey resolve to '' here — the
      // exact condition that used to make the app hang forever on
      // startup (see the Android "stuck on the native launch screen"
      // bug): Supabase.initialize() would call into its
      // _SecureSessionStorage's async secure-storage reads with a
      // meaningless empty URL/key and never resolve, main() never
      // reached runApp(), and the native splash placeholder never got
      // replaced — with no crash and no log line to explain why.
      //
      // The fix (lib/core/network/supabase_client.dart) checks for
      // empty config *before* ever touching Supabase.initialize or
      // secure storage, so this now fails synchronously and loudly
      // instead. The 5s timeout is the actual regression assertion —
      // a StateError proves it failed fast, but only a timeout proves
      // it didn't quietly hang first.
      await expectLater(
        KumoSupabaseClient.initialize(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('--dart-define-from-file'),
          ),
        ),
      );
    }, timeout: const Timeout(Duration(seconds: 5)));
  });
}
