import Combine
import UIKit
import UserNotifications
import FirebaseCore
import FirebaseMessaging
import FirebaseAppCheck

final class AttestFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        AppAttestProvider(app: app)
    }
}

final class NotificationService: NSObject, ObservableObject, UIApplicationDelegate,
                                 UNUserNotificationCenterDelegate, MessagingDelegate {
    static let shared = NotificationService()
    @Published var allowed = false
    @Published var errorMessage: String?
    @Published var latestDhikr: String?
    private(set) var token: String?
    var onToken: (() -> Void)?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // A missing configuration is a visible setup state, never a Firebase crash.
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            #if targetEnvironment(simulator)
            AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
            #else
            AppCheck.setAppCheckProviderFactory(AttestFactory())
            #endif
            FirebaseApp.configure()
            Messaging.messaging().delegate = Self.shared
        }
        UNUserNotificationCenter.current().delegate = Self.shared
        Task { await Self.shared.refreshPermission() }
        return true
    }

    @MainActor
    func refreshPermission() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        allowed = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
        if allowed && FirebaseApp.app() != nil { UIApplication.shared.registerForRemoteNotifications() }
    }

    @MainActor
    func requestPermission() async {
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            await refreshPermission()
            if !allowed { errorMessage = "يمكنك تفعيل الإشعارات من إعدادات الآيفون." }
        } catch { errorMessage = "تعذّر تفعيل الإشعارات. حاولي مرة أخرى." }
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        guard FirebaseApp.app() != nil else { return }
        Messaging.messaging().apnsToken = deviceToken
        Messaging.messaging().token { token, error in
            DispatchQueue.main.async {
                if let token { Self.shared.accept(token) }
                else if error != nil { Self.shared.errorMessage = "تعذّر تجهيز الإشعارات. افتحي التطبيق مجدداً." }
            }
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        DispatchQueue.main.async { Self.shared.errorMessage = "تعذّر تسجيل الإشعارات. تحققي من الاتصال وإعداد التطبيق." }
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        DispatchQueue.main.async { self.accept(fcmToken) }
    }

    private func accept(_ newToken: String) {
        token = newToken
        onToken?() // Re-register rotations and retry on subsequent foreground refreshes.
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        DispatchQueue.main.async { self.latestDhikr = response.notification.request.content.body }
        completionHandler()
    }
}
