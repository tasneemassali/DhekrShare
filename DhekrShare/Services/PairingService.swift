import Combine
import Foundation
import UIKit
import FirebaseCore
import FirebaseAuth
import FirebaseFunctions

@MainActor
final class PairingService: ObservableObject {
    @Published var configured = false
    @Published var ready = false
    @Published var paired = false
    @Published var busy = false
    @Published var coolingDown = false
    @Published var code: String?
    @Published var message: String?
    @Published var confirmation: String?
    private var refreshing = false
    private var registeredToken: String?
    private var functions: Functions { Functions.functions(region: "us-central1") }

    func start() async {
        configured = FirebaseApp.app() != nil
        guard configured else { return }
        NotificationService.shared.onToken = { [weak self] in
            Task { @MainActor in await self?.syncToken() }
        }
        do {
            if Auth.auth().currentUser == nil { _ = try await Auth.auth().signInAnonymously() }
            ready = true
            await refresh()
        } catch { message = "تعذّر الاتصال. تحققي من الإنترنت ثم أعيدي المحاولة." }
    }

    func refresh() async {
        guard ready, !refreshing else { return }
        refreshing = true
        defer { refreshing = false }
        do {
            let result = try await functions.httpsCallable("pairStatus").call()
            paired = (result.data as? [String: Any])?["paired"] as? Bool ?? false
            if paired { code = nil }
            await syncToken()
        } catch { message = friendly(error) }
    }

    func syncToken() async {
        guard ready, let token = NotificationService.shared.token, token != registeredToken,
              paired || code != nil else { return }
        do {
            _ = try await functions.httpsCallable("registerToken").call(["token": token])
            registeredToken = token
        } catch { message = "تعذّر حفظ إعداد الإشعارات. أبقي التطبيق مفتوحاً وحاولي التحديث." }
    }

    func create(setupKey: String) async {
        guard ready, !busy else { return }
        busy = true
        defer { busy = false }
        do {
            let result = try await functions.httpsCallable("createPair").call(["setupKey": setupKey])
            code = (result.data as? [String: Any])?["code"] as? String
            await syncToken()
        } catch { message = friendly(error) }
    }

    func join(_ input: String) async {
        guard ready, !busy else { return }
        let normalized = input.compactMap(\.wholeNumberValue).map(String.init).joined()
        guard normalized.count == 6 else { message = "أدخلي رمز الربط المكوّن من ستة أرقام."; return }
        busy = true
        defer { busy = false }
        do {
            _ = try await functions.httpsCallable("joinPair").call(["code": normalized])
            paired = true
            code = nil
            await syncToken()
        } catch { message = friendly(error) }
    }

    func send(_ dhikr: Dhikr) async {
        guard paired, !busy, !coolingDown else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        busy = true
        coolingDown = true
        confirmation = nil
        Task {
            try? await Task.sleep(for: .seconds(2))
            coolingDown = false
        }
        defer { busy = false }
        do {
            let result = try await functions.httpsCallable("sendDhikr").call(["dhikrID": dhikr.id])
            guard (result.data as? [String: Any])?["accepted"] as? Bool == true else {
                message = "تعذّر إرسال التذكير. حاولي مرة أخرى."
                return
            }
            confirmation = "تم الذكر ❤️"
            UIAccessibility.post(notification: .announcement, argument: confirmation)
        } catch { message = friendly(error) }
    }

    private func friendly(_ error: Error) -> String {
        let code = FunctionsErrorCode(rawValue: (error as NSError).code)
        switch code {
        case .resourceExhausted: return "انتظري قليلاً ثم حاولي مرة أخرى."
        case .permissionDenied: return "تحققي من مفتاح الإعداد وربط الجهاز."
        case .failedPrecondition: return "تحققي من رمز الربط وصلاحيته، وافتحي التطبيق وفعّلي الإشعارات على الجهاز الآخر."
        default: return "تعذّر إتمام الطلب. تحققي من الاتصال وإعداد التطبيق ثم حاولي مرة أخرى."
        }
    }
}
