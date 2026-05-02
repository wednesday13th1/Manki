import Foundation

enum EnglishGoalLevel: String, CaseIterable, Codable {
    case beginner
    case intermediate
    case advanced
    case eiken2
    case eikenPre1
    case eiken1
    case toefl80
    case toefl100
    case sat

    var displayName: String {
        switch self {
        case .beginner:
            return "Beginner"
        case .intermediate:
            return "Intermediate"
        case .advanced:
            return "Advanced"
        case .eiken2:
            return "Eiken 2"
        case .eikenPre1:
            return "Eiken Pre-1"
        case .eiken1:
            return "Eiken 1"
        case .toefl80:
            return "TOEFL 80"
        case .toefl100:
            return "TOEFL 100"
        case .sat:
            return "SAT"
        }
    }
}

extension Notification.Name {
    static let englishGoalLevelDidChange = Notification.Name("englishGoalLevelDidChange")
}

enum EnglishGoalLevelStore {
    static let storageKey = "englishGoalLevel"

    static var current: EnglishGoalLevel {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: storageKey),
                  let level = EnglishGoalLevel(rawValue: rawValue) else {
                return .intermediate
            }
            return level
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: storageKey)
            NotificationCenter.default.post(name: .englishGoalLevelDidChange, object: nil)
        }
    }
}
