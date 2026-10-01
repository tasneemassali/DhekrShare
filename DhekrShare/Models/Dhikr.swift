import Foundation

struct Dhikr: Identifiable {
    let id: Int
    let text: String
    var buttonTitle: String { text + " ❤️" }
    static let all = [
        "استغفر الله", "الحمد لله", "سبحان الله", "لا إله إلا الله",
        "الله أكبر", "لا حول ولا قوة إلا بالله", "اللهم صلِّ وسلم على نبينا محمد"
    ].enumerated().map { Dhikr(id: $0.offset, text: $0.element) }
}
