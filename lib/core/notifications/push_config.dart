/// Flip to `true` once BOTH of the following are done:
///
/// 1. An APNs key has been uploaded to the Firebase project (Firebase
///    console → Project settings → Cloud Messaging → Apple app
///    configuration).
/// 2. `ios/Runner/Runner.entitlements` (already added, wired into
///    `project.pbxproj` via `CODE_SIGN_ENTITLEMENTS`) is signed with a
///    provisioning profile that includes the Push Notifications capability —
///    enable "Push Notifications" under Signing & Capabilities for the
///    Runner target in Xcode so the profile gets regenerated with it.
///
/// `ios/Runner/GoogleService-Info.plist` is already in place (added when
/// Firebase Cloud Messaging was first wired up), so these two steps are all
/// that's left before iOS push can go live.
///
/// Until then, this stays `false` so `main.dart` skips Firebase
/// initialization on iOS entirely — with no APNs key configured,
/// `FirebaseMessaging.instance.getToken()` would just fail (safely, with a
/// caught error) rather than deliver anything, so there is no upside to
/// initializing it early.
const bool kIosPushReady = false;
