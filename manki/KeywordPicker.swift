import Foundation

protocol KeywordPicking {
    func pickKeywords(from lyrics: [TimedLyricLine], level: String) async -> [MankiKeyword]
}

final class KeywordPicker {
    static let shared = KeywordPicker()

    private let stopWords: Set<String> = [
        "the", "a", "an", "i", "you", "he", "she", "it",
        "we", "they", "is", "are", "was", "were",
        "and", "or", "but", "to", "of", "in", "on",
        "for", "with", "my", "your", "me", "mine", "yours",
        "our", "ours", "their", "theirs", "this", "that",
        "these", "those", "be", "been", "being", "am",
        "do", "does", "did", "done", "have", "has", "had",
        "not", "just", "from", "into", "over", "under",
        "then", "than", "when", "where", "what", "who",
        "why", "how", "yeah", "oh", "ah", "la", "na"
    ]

    private let easyWords: Set<String> = [
        "love", "baby", "night", "heart", "dance", "light",
        "dream", "world", "music", "happy", "smile", "feels"
    ]

    private init() {}

    func pickKeywords(from lyrics: [TimedLyricLine], level: String) -> [MankiKeyword] {
        guard !lyrics.isEmpty else { return [] }

        let normalizedLevel = level.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let maxKeywords = 8
        let targetRange = allowedDifficulties(for: normalizedLevel)
        var candidates: [Candidate] = []
        var seen = Set<String>()

        for (index, line) in lyrics.enumerated() {
            let startTime = line.time
            let endTime = index < lyrics.count - 1 ? lyrics[index + 1].time : nil
            let words = tokenize(line.text)

            for rawWord in words {
                let word = normalize(rawWord)

                guard shouldKeep(word) else { continue }
                guard !seen.contains(word) else { continue }

                let difficulty = estimateDifficulty(word)
                guard targetRange.contains(difficulty) else { continue }

                seen.insert(word)
                candidates.append(
                    Candidate(
                        keyword: MankiKeyword(
                            word: word,
                            meaning: "意味はAIまたは辞書で補完予定",
                            example: line.text,
                            difficulty: difficulty.rawValue,
                            lyricLineIndex: index,
                            startTime: startTime,
                            endTime: endTime,
                            reason: makeReason(for: word, line: line.text, difficulty: difficulty)
                        ),
                        score: score(word: word, lineIndex: index, totalLines: lyrics.count, difficulty: difficulty)
                    )
                )
            }
        }

        return candidates
            .sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    return (lhs.keyword.lyricLineIndex ?? .max) < (rhs.keyword.lyricLineIndex ?? .max)
                }
                return lhs.score > rhs.score
            }
            .prefix(maxKeywords)
            .map(\.keyword)
    }

    private func tokenize(_ text: String) -> [String] {
        text
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    private func normalize(_ word: String) -> String {
        word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func shouldKeep(_ word: String) -> Bool {
        guard !stopWords.contains(word) else { return false }
        guard !easyWords.contains(word) else { return false }
        guard word.count >= 4 else { return false }
        guard word.rangeOfCharacter(from: .decimalDigits) == nil else { return false }
        return true
    }

    private func estimateDifficulty(_ word: String) -> KeywordDifficulty {
        if word.count >= 9 || word.hasSuffix("tion") || word.hasSuffix("ment") || word.hasSuffix("ness") {
            return .hard
        }
        if word.count >= 6 || word.hasSuffix("ing") || word.hasSuffix("ive") || word.hasSuffix("ous") {
            return .medium
        }
        return .easy
    }

    private func allowedDifficulties(for level: String) -> Set<KeywordDifficulty> {
        switch level {
        case "beginner", "easy", "a1", "a2":
            return [.easy, .medium]
        case "advanced", "hard", "c1", "c2":
            return [.medium, .hard]
        default:
            return [.medium]
        }
    }

    private func score(word: String,
                       lineIndex: Int,
                       totalLines: Int,
                       difficulty: KeywordDifficulty) -> Int {
        var score = min(word.count, 10)

        if difficulty == .medium {
            score += 4
        } else if difficulty == .hard {
            score += 2
        }

        let middleStart = max(0, totalLines / 3)
        let middleEnd = min(totalLines - 1, (totalLines * 2) / 3)
        if lineIndex >= middleStart && lineIndex <= middleEnd {
            score += 3
        }

        return score
    }

    private func makeReason(for word: String, line: String, difficulty: KeywordDifficulty) -> String {
        let difficultyLabel: String
        switch difficulty {
        case .easy:
            difficultyLabel = "基礎より少し上"
        case .medium:
            difficultyLabel = "学習価値が高い"
        case .hard:
            difficultyLabel = "少し難しいが印象に残りやすい"
        }

        if line.lowercased().contains(word) {
            return "歌詞の中で印象的に使われており、\(difficultyLabel)単語"
        }
        return "曲の流れの中で目立ちやすく、\(difficultyLabel)単語"
    }
}

final class LocalKeywordPicker: KeywordPicking {
    func pickKeywords(from lyrics: [TimedLyricLine], level: String) async -> [MankiKeyword] {
        KeywordPicker.shared.pickKeywords(from: lyrics, level: level)
    }
}

// Future AIKeywordPicker prompt example:
// 「以下の英語歌詞から、英語学習者が覚える価値のある単語を最大8個選んでください。
// 条件：
// - 簡単すぎる単語は除外
// - 曲の印象的な部分に出てくる単語を優先
// - 各単語について意味、日本語訳、例文、難易度、選んだ理由を返してください」

private enum KeywordDifficulty: String {
    case easy
    case medium
    case hard
}

private struct Candidate {
    let keyword: MankiKeyword
    let score: Int
}
