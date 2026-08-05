---
name: deploy
description: Build and release Kumo to the App Store / Google Play (fastlane lanes, per-platform build commands). Use when the user asks to build a release, deploy, or ship to App Store/Google Play.
---

## Deployment

### Environments

```
Development → Staging → Production
  (debug)    (release)   (release)
```

### Build & Release

```bash
# iOS
flutter build ios --release

# Android
flutter build apk --release

# App Store
cd ios && fastlane deploy_app_store

# Google Play
cd android && fastlane deploy_google_play
```

