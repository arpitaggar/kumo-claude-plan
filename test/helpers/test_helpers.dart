import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/network/supabase_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Dummy JWT — well-formed but points at a non-existent project.
// GoTrue never makes outbound HTTP calls when no session is stored.
const _kTestUrl = 'https://test.supabase.co';
const _kTestAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
    '.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRlc3QiLCJyb2xlIjoiYW5vbiIsImlhdCI'
    '6MTY0MTc2OTIwMCwiZXhwIjo5OTk5OTk5OTk5fQ'
    '.dc_X5iR_VP_qroESh0ZDxbR7xA74JlEFKBHQdZST9ww';

/// Initialises a Supabase test instance with dummy credentials and wires it
/// into [KumoSupabaseClient].  Safe to call multiple times.
Future<void> initTestSupabase() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  // flutter_secure_storage (used by AuthLocalDataSource/KumoSupabaseClient's
  // session storage, see docs/SECURITY_AUDIT.md SEC-007/SEC-011) talks to a
  // real platform channel with no test-environment implementation — without
  // this, any widget that touches it during a test hangs pumpAndSettle
  // forever. The package ships this in-memory fake for exactly this case.
  FlutterSecureStoragePlatform.instance =
      TestFlutterSecureStoragePlatform(<String, String>{});
  late Supabase instance;
  try {
    instance = await Supabase.initialize(
      url: _kTestUrl,
      publishableKey: _kTestAnonKey,
    );
  } catch (_) {
    // Already initialised in a shared isolate — grab the existing singleton.
    instance = Supabase.instance;
  }
  KumoSupabaseClient.setInstanceForTesting(instance);
}
