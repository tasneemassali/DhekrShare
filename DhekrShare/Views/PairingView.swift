import SwiftUI

struct PairingView: View {
    @EnvironmentObject private var pairing: PairingService
    @Environment(\.dismiss) private var dismiss
    @State private var setupKey = ""
    @State private var input = ""

    var body: some View {
        NavigationStack {
            Form {
                if pairing.paired {
                    Section { Label("الجهازان مرتبطان ❤️", systemImage: "checkmark.circle") }
                } else {
                    Section("الجهاز الأول") {
                        SecureField("مفتاح الإعداد الخاص", text: $setupKey)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                            .environment(\.layoutDirection, .leftToRight)
                        Text("مفتاح خاص من إعداد الخادم، يُستخدم لإنشاء الربط فقط.")
                            .font(.caption).foregroundStyle(.secondary)
                        Button("إنشاء رمز ربط") {
                            Task { await pairing.create(setupKey: setupKey); setupKey = "" }
                        }.disabled(setupKey.isEmpty || pairing.busy)
                        if let code = pairing.code {
                            Text(code).font(.largeTitle.monospacedDigit()).textSelection(.enabled)
                                .environment(\.layoutDirection, .leftToRight)
                            Text("شاركي الرمز مع الجهاز الآخر. صالح لعشر دقائق.").font(.footnote)
                        }
                    }
                    Section("الجهاز الآخر") {
                        TextField("إدخال رمز الربط", text: $input).keyboardType(.numberPad)
                            .environment(\.layoutDirection, .leftToRight)
                        Button("ربط") { Task { await pairing.join(input) } }
                            .disabled(input.isEmpty || pairing.busy)
                    }
                    Section {
                        Button("تحديث حالة الربط") { Task { await pairing.refresh() } }
                        Text("بعد الربط، افتحي التطبيق على الجهازين وفعّلي الإشعارات.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                if pairing.busy { ProgressView() }
            }
            .navigationTitle("ربط الجهازين")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("تم") { dismiss() } } }
            .task {
                while !Task.isCancelled && !pairing.paired {
                    try? await Task.sleep(for: .seconds(5))
                    if !Task.isCancelled { await pairing.refresh() }
                }
            }
            .alert("تنبيه", isPresented: Binding(get: { pairing.message != nil }, set: { if !$0 { pairing.message = nil } })) {
                Button("حسناً") { pairing.message = nil }
            } message: { Text(pairing.message ?? "") }
        }.environment(\.layoutDirection, .rightToLeft)
    }
}
