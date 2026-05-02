import Foundation

struct LyricKeyword: Hashable {
    let word: String
    let sourceLine: String
    let level: EnglishGoalLevel
    let reason: String
}

final class LyricKeywordExtractor {
    private static let stopWords: Set<String> = [
        "a", "an", "and", "are", "am", "as", "at", "be", "been", "being", "but", "by",
        "did", "do", "does", "for", "from", "had", "has", "have", "he", "her", "hers",
        "him", "his", "i", "if", "in", "into", "is", "it", "its", "me", "my", "of", "on",
        "or", "our", "ours", "she", "so", "than", "that", "the", "their", "them", "they",
        "this", "to", "too", "up", "us", "was", "we", "were", "with", "you", "your", "yours"
    ]

    private static let phraseBank: [EnglishGoalLevel: [String]] = [
        .advanced: ["fade away", "hold on", "let go", "break down", "look back"],
        .eikenPre1: ["carry on", "turn around", "fall apart"],
        .eiken1: ["draw the line", "walk away", "come undone"],
        .toefl80: ["take control", "let go", "move on"],
        .toefl100: ["carry on", "figure out", "hold back"],
        .sat: ["fade away", "look back", "fall apart"]
    ]

    private static let levelWordBank: [EnglishGoalLevel: Set<String>] = [
        .beginner: ["dream", "heart", "light", "night", "smile", "stars", "world", "shine", "shadow", "broken"],
        .intermediate: ["promise", "memory", "lonely", "breathing", "echoes", "silence", "midnight", "glowing", "fragile", "pretend"],
        .advanced: ["gravity", "illusion", "mercy", "surrender", "haunted", "restless", "shattered", "horizon", "whispering", "lingering"],
        .eiken2: ["future", "reason", "change", "answer", "voice", "moment", "battle", "healing", "courage", "regret"],
        .eikenPre1: ["conflict", "isolate", "resolve", "constant", "distant", "depth", "reflection", "survive", "restore", "measure"],
        .eiken1: ["destiny", "collapse", "dignity", "persistent", "narrative", "complexity", "identity", "resistance", "inevitable", "paradox"],
        .toefl80: ["context", "impact", "respond", "structure", "resource", "process", "decline", "recover", "assume", "significant"],
        .toefl100: ["allocate", "derive", "notion", "constrain", "dimension", "justify", "simulate", "hypothesis", "interpret", "coherent"],
        .sat: ["fleeting", "solemn", "tender", "melancholy", "yearning", "vivid", "subtle", "endure", "obscure", "fracture"]
    ]

    static func extract(from lyrics: [TimedLyricLine], goalLevel: EnglishGoalLevel) -> [LyricKeyword] {
        guard !lyrics.isEmpty else { return [] }

        var results: [LyricKeyword] = []
        var seen = Set<String>()

        for phrase in phraseBank[goalLevel] ?? [] {
            guard let sourceLine = lyrics.first(where: { normalizedLine($0.text).contains(phrase) })?.text else { continue }
            let key = phrase.lowercased()
            guard seen.insert(key).inserted else { continue }
            results.append(LyricKeyword(word: phrase, sourceLine: sourceLine, level: goalLevel, reason: reason(for: goalLevel, candidate: phrase, isPhrase: true)))
        }

        for line in lyrics {
            let normalized = normalizedLine(line.text)
            let tokens = normalized.split(separator: " ").map(String.init)
            for token in tokens {
                guard shouldInclude(token, for: goalLevel) else { continue }
                let key = token.lowercased()
                guard seen.insert(key).inserted else { continue }
                results.append(LyricKeyword(word: token, sourceLine: line.text, level: goalLevel, reason: reason(for: goalLevel, candidate: token, isPhrase: false)))
            }
        }

        return Array(results.prefix(12))
    }

    private static func shouldInclude(_ token: String, for level: EnglishGoalLevel) -> Bool {
        guard token.count >= minimumLength(for: level),
              token.rangeOfCharacter(from: CharacterSet.letters.inverted) == nil,
              !stopWords.contains(token) else {
            return false
        }

        if let bank = levelWordBank[level], bank.contains(token) {
            return true
        }

        switch level {
        case .beginner:
            return (4...6).contains(token.count)
        case .intermediate, .eiken2:
            return token.count >= 6
        case .advanced, .eikenPre1, .toefl80:
            return token.count >= 7
        case .eiken1, .toefl100, .sat:
            return token.count >= 8
        }
    }

    private static func minimumLength(for level: EnglishGoalLevel) -> Int {
        switch level {
        case .beginner:
            return 4
        case .intermediate, .eiken2:
            return 5
        case .advanced, .eikenPre1, .toefl80:
            return 6
        case .eiken1, .toefl100, .sat:
            return 7
        }
    }

    private static func normalizedLine(_ line: String) -> String {
        let lowered = line.lowercased()
        let transformed = lowered.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) || CharacterSet.whitespaces.contains(scalar)
                ? Character(scalar)
                : " "
        }
        return String(transformed).replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func reason(for level: EnglishGoalLevel, candidate _: String, isPhrase: Bool) -> String {
        if isPhrase {
            return "\(level.displayName) 向けのフレーズ表現"
        }

        switch level {
        case .beginner:
            return "基本語彙として歌詞の中で覚えやすい単語"
        case .intermediate:
            return "日常会話でも使いやすい中級語彙"
        case .advanced:
            return "抽象度が高く表現力のある語彙"
        case .eiken2:
            return "英検2級レベルを意識した高校語彙"
        case .eikenPre1:
            return "英検準1級向けの抽象語彙"
        case .eiken1:
            return "英検1級向けの難度が高い語彙"
        case .toefl80:
            return "TOEFL 80 向けの基礎アカデミック語彙"
        case .toefl100:
            return "TOEFL 100 向けの発展アカデミック語彙"
        case .sat:
            return "SAT 向けの抽象的・文学的語彙"
        }
    }
}
