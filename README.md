# DhekrShare — ذِكر ❤️

A private, Arabic-first native iPhone app for exactly two paired devices. Tap one of seven dhikr buttons to request a reminder on the other iPhone. No sender names, profiles, phone numbers, contacts, Android app, or website.

## What is implemented

- SwiftUI, iOS 17+, forced RTL, warm light/dark appearance, Dynamic Type, generous rounded buttons.
- Soft haptic feedback and exact successful-send confirmation **تم الذكر ❤️**.
- Two-second client and transactional server cooldown. Confirmation appears only after Firebase accepts the push; it is not proof of delivery.
- One private pair per Firebase installation. Six-digit single-use pairing codes expire after ten minutes.
- Notification permission, APNs registration, FCM token rotation/re-registration, foreground banners, and opening received reminders.
- Safe setup screen when Firebase configuration is missing; sending is disabled, not simulated.
- Serverless backend, deny-all Firestore client rules, unit tests, and an unsigned simulator build workflow.

## Architecture and backend choice

SwiftUI → Firebase callable Cloud Functions → private Firestore pair/device records → Firebase Cloud Messaging → Apple Push Notification service → other iPhone.

Firebase Authentication silently creates an anonymous device account; there is no login screen. Functions verify its ID token and Firebase App Check, select the paired recipient themselves, and accept only the seven predefined dhikr IDs. The iPhone never chooses a recipient token or arbitrary notification text. Node.js 22 functions run in `us-central1`. No always-on server or service-account file is needed: deployed functions use their managed runtime identity.

## Project structure

```
DhekrShare.xcodeproj/       Ready-to-open Xcode project and shared scheme
DhekrShare/App/             SwiftUI entry point
DhekrShare/Views/           Home and pairing screens
DhekrShare/Models/          Seven dhikr values
DhekrShare/Services/        Pairing and notification integration
DhekrShare/Resources/       Info, entitlements, app icon
Config/                    Build settings and local-only Firebase configuration
backend/                   Callable functions, policy helpers, tests
firestore.rules            No direct client reads or writes
scripts/generate_project.py Reproducible project generator (Python standard library)
.github/workflows/         Backend checks and macOS simulator build
SETUP.md                   Beginner guide, starting from an iPhone
```

## Pairing flow

1. Administrator sets a strong private `PAIRING_SETUP_KEY` in Google Secret Manager through Firebase CLI. This prevents strangers from claiming your installation before you do.
2. First iPhone enters that key in the secure setup field and taps **إنشاء رمز ربط**. The key is not persisted by the app. Share only the resulting six-digit code with your sister.
3. Second iPhone enters the code under **إدخال رمز الربط**. A Firestore transaction consumes the code and completes the pair. Third devices are refused.
4. The first phone refreshes automatically while its pairing screen is open, or on foreground/manual refresh. Open both phones and enable notifications so their current tokens are registered.

No public reset endpoint exists. If an anonymous identity is lost after reinstall/device replacement, an administrator must delete `private/pair`, all documents in `devices` and `limits`, then pair again. Rotate the setup key if exposed. Do not enable automatic cleanup of anonymous users for this installation; it could remove long-lived device identities.

## Push flow

Permission → APNs device token → FCM registration token → authenticated `registerToken` callable. Refresh callbacks and foreground checks retry registration. A tap calls `sendDhikr` with a numeric allowlisted ID. The server checks membership, recipient readiness, and cooldown, then sends:

- Title: **تذكير ❤️**
- Body: selected dhikr without the button's heart (for example **الحمد لله**).

FCM/APNs delivery is best effort. Network availability, Focus, notification permissions, and iOS settings affect visibility. Undelivered notifications expire after one hour. Ambiguous network failures are not retried automatically, to avoid duplicate reminders. A failed send displays an Arabic error instead of the success confirmation.

## Security and privacy

- No APNs `.p8`, signing certificates, passwords, service-account keys, or setup secret in source control.
- Real `GoogleService-Info.plist` and local signing settings are gitignored. Firebase's client configuration is not a server credential, but is kept local here.
- APNs keys belong only in Firebase Console. `PAIRING_SETUP_KEY` belongs in Secret Manager and the first phone's transient secure field.
- App Attest protects physical-device callable access; simulator-only debug provider requires its debug token to be registered privately in Firebase.
- Server-side Auth, App Check, fixed pairing capacity, short-lived hashed codes, failed-attempt throttles, and send cooldowns.
- FCM tokens and anonymous UIDs are server-only. No message history is stored. Operational timestamps/rate-limit records remain until an administrator deletes them.
- Firebase/Google and Apple process notification content; this is not end-to-end encrypted. Device lock-screen settings control whether the dhikr preview is visible.
- Rate limits reduce abuse; they do not guarantee a spending cap. Enable billing alerts and monitor anonymous Auth/function traffic.

## Build, configure, and test

Read [SETUP.md](SETUP.md) for exact steps. You need a Firebase project with anonymous Auth, Firestore, App Check, deployed functions (Blaze billing), and an APNs key uploaded to Firebase. Use the same bundle identifier in Apple, Firebase, and `Config/Local.xcconfig`.

On a Mac with Xcode 16 or newer, open `DhekrShare.xcodeproj`; packages resolve automatically. The app targets iOS 17+. For an unsigned simulator check:

```sh
xcodebuild -project DhekrShare.xcodeproj -scheme DhekrShare \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Backend checks:

```sh
cd backend
npm ci
npm run check
npm test
```

Unit tests cover policy helpers, not deployed Firebase integration. CI builds Swift on a macOS runner; a green build does not prove delivery on physical phones. Run the two-iPhone acceptance checklist in SETUP before relying on notifications.

## Apple account requirements

A normal Apple ID lets you access developer resources and use Xcode's limited Personal Team local-device testing on a Mac. Simulator UI development does not require paid membership. The full push-enabled app needs Apple Developer Program capabilities and valid provisioning; Personal Team is not sufficient for this architecture. Private TestFlight distribution also requires paid membership and App Store Connect setup. An iPhone alone cannot run Xcode or compile/sign this project. A remote Mac or someone with a Mac can perform the documented build and upload; both phones can then install via TestFlight. TestFlight builds expire after 90 days and need replacement builds.

Official references:
- [Apple membership comparison](https://developer.apple.com/support/compare-memberships/)
- [Enroll from the Apple Developer app](https://developer.apple.com/help/account/membership/enrolling-in-the-app/)
- [Firebase Apple push setup](https://firebase.google.com/docs/cloud-messaging/ios/get-started)
- [App Attest setup](https://firebase.google.com/docs/app-check/ios/app-attest-provider)
- [Firebase Functions deployment and billing](https://firebase.google.com/docs/functions/get-started)
