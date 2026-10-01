import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var pairing: PairingService
    @EnvironmentObject private var notifications: NotificationService
    @Environment(\.colorScheme) private var scheme
    @State private var showPairing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 12) {
                        Text("ذِكر ❤️").font(.largeTitle.bold())
                        Text("ذكرٌ بين قلبين").font(.title3).foregroundStyle(.secondary)
                    }.padding(.vertical, 20)
                    if !pairing.configured {
                        Text("مرحباً بكِ. يلزم إكمال إعداد التطبيق لتفعيل الربط والإشعارات.")
                            .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    } else if !pairing.ready {
                        Button("إعادة الاتصال") { Task { await pairing.start() } }
                    } else if !pairing.paired {
                        Button("ربط الجهازين") { showPairing = true }
                            .buttonStyle(.borderedProminent).tint(.red.opacity(0.75))
                    }
                    if pairing.configured && !notifications.allowed {
                        Button("تفعيل الإشعارات") { Task { await notifications.requestPermission() } }
                        Button("فتح الإعدادات") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                        }.font(.caption)
                    }
                    ForEach(Dhikr.all) { dhikr in
                        Button { Task { await pairing.send(dhikr) } } label: {
                            Text(dhikr.buttonTitle)
                                .font(.system(.title3, design: .rounded).weight(.medium))
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity, minHeight: 42)
                                .padding(18)
                                .background(scheme == .dark ? Color(.secondarySystemBackground) : .white,
                                            in: RoundedRectangle(cornerRadius: 24))
                                .overlay(RoundedRectangle(cornerRadius: 24).stroke(.red.opacity(0.08)))
                        }
                        .buttonStyle(.plain)
                        .disabled(!pairing.paired || pairing.busy || pairing.coolingDown)
                    }
                    if let confirmation = pairing.confirmation {
                        Text(confirmation).font(.headline).foregroundStyle(.primary)
                            .accessibilityIdentifier("sendConfirmation")
                    }
                    if pairing.busy { ProgressView().accessibilityLabel("جارٍ إتمام الطلب") }
                    if let text = notifications.latestDhikr {
                        VStack(spacing: 8) {
                            Text("تذكير ❤️").font(.caption).foregroundStyle(.secondary)
                            Text(text).font(.title3)
                        }.padding()
                    }
                    if let error = notifications.errorMessage {
                        Text(error).font(.footnote).foregroundStyle(.secondary)
                    }
                }.padding(24).frame(maxWidth: 560).frame(maxWidth: .infinity)
            }
            .background(scheme == .dark ? Color(.systemBackground) : Color(red: 0.98, green: 0.96, blue: 0.93))
            .toolbar {
                if pairing.ready {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showPairing = true } label: { Image(systemName: "link") }
                            .accessibilityLabel("ربط الجهازين")
                    }
                }
            }
            .sheet(isPresented: $showPairing) { PairingView() }
            .alert("تنبيه", isPresented: Binding(get: { pairing.message != nil }, set: { if !$0 { pairing.message = nil } })) {
                Button("حسناً") { pairing.message = nil }
            } message: { Text(pairing.message ?? "") }
        }.tint(.red.opacity(0.8))
    }
}
