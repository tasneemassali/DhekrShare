# SETUP — starting from your iPhone

The code is prepared. It is not yet an installed or deployed app. GitHub stores the project; it does not automatically install it on your phone. You do not need to download source folders to your iPhone.

## Your ONE next action

Open [Apple Developer enrollment](https://developer.apple.com/programs/enroll/) in Safari on your iPhone and start enrolling your normal Apple ID in the **Apple Developer Program as an individual**. Apple may direct you to its Apple Developer app for identity verification and payment. Check the fee displayed before purchasing. If in-app enrollment is unavailable in your region, use Apple's website/support route. Do not send your password or identity documents in chat.

This paid membership is required for this project's real APNs push notifications and TestFlight route. It does not by itself compile or install the app. After approval, the remaining setup below can be done with help on a Mac or a remote Mac. You do not have to buy a Mac.

## What you can do now without paying Apple

- Read and edit this repository on GitHub from Safari.
- Run the repository's **Check app and backend** GitHub Actions workflow, if enabled. Its macOS job builds an unsigned simulator app without Apple or Firebase credentials. GitHub runner usage can have its own limits/costs.
- Have someone with Xcode view the Arabic interface in the simulator. With no Firebase configuration, the UI displays a setup message and cannot send.
- Create a Firebase project. Live Cloud Functions deployment requires Firebase Blaze billing separately.

You cannot install a GitHub source ZIP or the unsigned simulator build on an iPhone. A free Apple ID's Personal Team is not a workaround for this app's push capability.

## After enrollment: arrange a Mac build session

Use a trusted person with a Mac and current Xcode, or a remote Mac you control through a remote desktop. The following instructions are for that session. A browser-only Linux terminal can deploy Firebase, but cannot build the iOS app. Never share your Apple password with a helper; sign in yourself. A remote Mac must support Apple signing and access to App Store Connect.

1. Clone `https://github.com/tasneemassali/DhekrShare.git`, or download/unzip its source on the Mac.
2. Open **DhekrShare.xcodeproj** in Xcode. Wait for Firebase Swift packages to finish resolving.
3. Copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig`.
4. Put your Apple Team ID and a unique bundle ID in the local file. Example bundle ID: `com.tasneemassali.DhekrShare`. If Apple says it is unavailable, choose another and use it everywhere below.
5. In Xcode Settings → Accounts, sign in to your Apple developer account. Select the app target → Signing & Capabilities → your paid team. Keep automatic signing on.
6. Ensure **Push Notifications** and **App Attest** are enabled for the App ID in your Apple developer account and target. The checked-in entitlements use development APNs for Debug and production APNs for Release; App Attest uses production. Refresh provisioning if capabilities changed.

## Firebase: create the private backend

Use [Firebase Console](https://console.firebase.google.com/). On an iPhone, Safari's Request Desktop Website may make the console easier, but the Mac session is simplest.

1. Create a project named DhekrShare. Google Analytics is optional and not needed by this app.
2. Add an **iOS app** using the exact bundle ID chosen above.
3. Download **GoogleService-Info.plist**. Place it at `Config/GoogleService-Info.plist` on the Mac. Do not commit it. The Xcode build copies it into the app automatically; do not add a duplicate resource entry.
4. Open Authentication → Sign-in method and enable **Anonymous**. There are no email/password users. Keep automatic anonymous-user cleanup disabled.
5. Create Cloud Firestore in production mode, preferably near `us-central1`. The deployed rules will deny every direct client read/write.
6. Upgrade to **Blaze** to deploy Cloud Functions. Review billing and set a budget alert. Alerts are not hard spending caps.
7. Open App Check, select the iOS app, and register **App Attest** with the Apple Team ID. Functions enforce App Check in code. Do not switch enforcement off to fix setup errors.

### Deploy from Terminal (Mac or an authenticated cloud terminal)

Install Node.js 22 and Firebase CLI. In the repository directory:

```sh
npm install -g firebase-tools
firebase login
cd backend
npm ci
npm test
cd ..
firebase functions:secrets:set PAIRING_SETUP_KEY --project YOUR_FIREBASE_PROJECT_ID
```

Replace `YOUR_FIREBASE_PROJECT_ID` with your project's actual ID, not its display name. When prompted for the secret, enter a newly generated random string of at least 32 characters from a password manager. Save it privately: you will type it on the **first iPhone only**. Do not put it in code, screenshots, commits, or chat.

Then deploy:

```sh
firebase deploy --only functions,firestore:rules --project YOUR_FIREBASE_PROJECT_ID
```

Approve creation of required Google Cloud services if prompted. Functions use their own runtime identity; **do not download a service-account JSON key**. Keep function region `us-central1` unless you also change the Swift service region.

## Connect Apple push notifications

1. In [Apple Developer account](https://developer.apple.com/account/), open Certificates, Identifiers & Profiles → Keys.
2. Create an APNs-enabled key appropriate for your app/team. Download the `.p8` file once and store it securely. Record the Key ID and Team ID privately.
3. In Firebase → Project Settings → Cloud Messaging → your iOS app, upload the APNs authentication key and enter Key ID/Team ID. If Apple's key is environment-scoped, configure keys matching both development and production as appropriate. TestFlight uses production APNs.
4. Never copy the `.p8` into this repository. No Apple private key belongs inside the app.

Official [Firebase APNs instructions](https://firebase.google.com/docs/cloud-messaging/ios/get-started) and [Apple App Check instructions](https://firebase.google.com/docs/app-check/ios/app-attest-provider).

## First build and private installation on two phones

Both phones must run iOS 17 or later. **TestFlight** is convenient when the Mac is remote and cannot connect directly to your iPhones.

1. In [App Store Connect](https://appstoreconnect.apple.com/), create an iOS app record named DhekrShare using your registered bundle ID. A SKU is your own internal label, e.g. `dhekrshare-private-1`.
2. In Xcode choose the DhekrShare scheme and a generic iOS device destination, then Product → Archive.
3. In Organizer choose Distribute App → App Store Connect → Upload. Resolve any signing/account agreement requests using your own account. Never disable App Check or commit credentials to bypass an error.
4. Wait for processing in App Store Connect → TestFlight. Complete required compliance/beta fields honestly. The app uses platform/Firebase TLS and declares no non-exempt custom encryption; adjust this declaration if you later change the cryptography.
5. Invite your own account as an internal tester if eligible. For your sister, use a private external tester invitation to her email. The first external build normally requires Apple's Beta App Review; approval is not instant or guaranteed. Do not enable a public invitation link. Provide review access/instructions when Apple requests them; a separate review Firebase project avoids occupying your private two-device pair.
6. On both iPhones, install Apple's TestFlight app, accept the invitations, and install DhekrShare. TestFlight builds expire in 90 days: increment build number and upload a replacement before expiry.

Alternative: when both phones can connect to the Mac, use Xcode's Run with paid development provisioning and enable Developer Mode when iOS asks. This avoids TestFlight review but needs physical device provisioning and does not eliminate membership requirements.

## Pair the two iPhones

1. Open the app on both phones and tap **تفعيل الإشعارات**, then Allow. If previously denied, use **فتح الإعدادات** and allow notifications there.
2. On your phone tap **ربط الجهازين**, enter the private setup key in **مفتاح الإعداد الخاص**, then **إنشاء رمز ربط**.
3. Give your sister the displayed six-digit code. Do not give her the setup key; she does not need it.
4. On her phone tap **ربط الجهازين** → **إدخال رمز الربط**, enter the code, and tap **ربط** within ten minutes.
5. Keep the first phone's pairing screen open until **الجهازان مرتبطان ❤️**, or tap **تحديث حالة الربط**. Open both apps again to register notification tokens. Tap **تم** to return home.
6. On your phone tap **استغفر الله ❤️**. You should see exactly **تم الذكر ❤️** once the push service accepts it. Your sister should receive title **تذكير ❤️** and body **استغفر الله**.
7. Send a reminder back from her phone.

## Acceptance checklist on real phones

- Send all seven choices in both directions; check exact Arabic text and absence of names.
- Try rapid taps: buttons pause for about two seconds and server rejects faster requests.
- Background/lock the receiver and test again; also check foreground banners and opening a notification.
- Deny notification permission, then enable it in Settings; reopen both apps and check recovery.
- Turn sender networking off: no false success should appear. Reconnect and retry manually.
- Test dark mode and larger text; scroll to reach all buttons.
- Check incorrect/expired pairing codes, using the code on the creator phone, and rejecting a third device. Do code-expiry checks before completing the pair or in a separate test Firebase project.
- Restart both phones and verify the pair still works. Do not delete the app just to test restart.

## Troubleshooting and recovery

- **Setup message:** `Config/GoogleService-Info.plist` was missing during build. Add it locally and rebuild.
- **App Check error:** verify bundle ID/Team ID, App Attest registration and production entitlement. Physical phones use App Attest even in Debug. Simulator builds use the debug provider: register the generated debug token privately in Firebase App Check; never commit it. A simulator is not the final push test.
- **Paired but send fails:** enable notifications and reopen both apps so tokens are uploaded, then retry. Check APNs key, Firebase project, deployment, billing, and signing configuration.
- **Success but no banner:** acceptance is not a receipt. Check Focus, notification settings, connectivity, and APNs credentials; test while receiver is foregrounded. Do not repeatedly tap to compensate.
- **Code expired:** first device creates another code with its setup key. Only the original owner can regenerate a pending pair.
- **Replaced/reinstalled phone:** anonymous identity may be lost. As Firebase administrator, delete document `private/pair` and all documents in `devices` and `limits`, then repeat pairing on both phones. There is deliberately no public takeover/reset function.
- **Stop using the app:** administrator deletes these records and the two anonymous Auth users; disable/delete functions if the project is no longer needed.

No full end-to-end result can be certified until your actual Apple/Firebase setup and two physical phones are available.
