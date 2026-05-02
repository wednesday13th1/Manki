import Foundation

struct ExtractedKeyword: Codable, Hashable {
    let id: UUID
    let word: String
    let meaning: String
    let japaneseMeaning: String
    let sourceLine: String
    let songTitle: String
    let artistName: String
    let goalText: String
    let difficulty: String
    let reason: String
    let createdAt: Date
}

extension ExtractedKeyword {
    func asSavedWord() -> SavedWord {
        SavedWord(
            english: word,
            japanese: japaneseMeaning.isEmpty ? meaning : japaneseMeaning,
            exampleSentence: sourceLine,
            illustrationScenario: "From: \(songTitle) - \(artistName)\nGoal: \(goalText)\nReason: \(reason)",
            illustrationImageFileName: nil,
            isFavorite: false,
            importanceLevel: mappedImportance()
        )
    }

    private func mappedImportance() -> Int {
        switch difficulty.lowercased() {
        case "beginner":
            return 1
        case "daily", "intermediate":
            return 2
        case "advanced", "advanced-academic", "music":
            return 4
        case "very-advanced", "toefl", "sat":
            return 5
        default:
            return 3
        }
    }
}

enum KeywordProfile: String, Codable, Hashable {
    case beginner
    case dailyConversation
    case intermediate
    case advancedAcademic
    case veryAdvanced
    case toefl
    case sat
    case musicUnderstanding

    var difficultyLabel: String {
        switch self {
        case .beginner:
            return "beginner"
        case .dailyConversation:
            return "daily"
        case .intermediate:
            return "intermediate"
        case .advancedAcademic:
            return "advanced-academic"
        case .veryAdvanced:
            return "very-advanced"
        case .toefl:
            return "toefl"
        case .sat:
            return "sat"
        case .musicUnderstanding:
            return "music"
        }
    }

    var defaultReason: String {
        switch self {
        case .beginner:
            return "初心者でも歌詞の中で覚えやすい基本語彙です。"
        case .dailyConversation:
            return "日常会話でそのまま使いやすい表現です。"
        case .intermediate:
            return "歌詞に頻出し、中級学習に役立つ語彙です。"
        case .advancedAcademic:
            return "英検準1級レベルの抽象語彙として役立ちます。"
        case .veryAdvanced:
            return "英検1級レベルの発展語彙として学習価値があります。"
        case .toefl:
            return "TOEFL対策で役立つ学術寄りの語彙です。"
        case .sat:
            return "SAT向けの抽象的・文学的な語彙です。"
        case .musicUnderstanding:
            return "洋楽の歌詞理解で頻出する表現です。"
        }
    }
}

enum GoalLevelInterpreter {
    static func inferKeywordProfile(from goalText: String) -> KeywordProfile {
        let text = goalText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if text.contains("初心者") || text.contains("初級") || text.contains("beginner") {
            return .beginner
        }
        if text.contains("日常会話") || text.contains("会話") || text.contains("conversation") {
            return .dailyConversation
        }
        if text.contains("英検1級") || text.contains("eiken 1") {
            return .veryAdvanced
        }
        if text.contains("英検準1級") || text.contains("準1") || text.contains("pre-1") {
            return .advancedAcademic
        }
        if text.contains("英検2級") || text.contains("eiken 2") {
            return .intermediate
        }
        if text.contains("toefl") {
            return .toefl
        }
        if text.contains("sat") {
            return .sat
        }
        if text.contains("洋楽") || text.contains("歌詞を理解") || text.contains("音楽") || text.contains("music") {
            return .musicUnderstanding
        }
        return .intermediate
    }
}

protocol KeywordExtracting {
    func extractKeywords(
        from lyrics: String,
        goalText: String,
        songTitle: String,
        artistName: String
    ) async throws -> [ExtractedKeyword]
}

final class LocalKeywordExtractor: KeywordExtracting {
    private struct LexiconEntry {
        let term: String
        let meaning: String
        let japaneseMeaning: String
        let profiles: Set<KeywordProfile>
        let difficulty: String
        let reason: String
        let isPhrase: Bool
    }

    private static let stopWords: Set<String> = [
        "the", "a", "an", "i", "you", "we", "he", "she", "it", "they", "is", "are", "am",
        "was", "were", "do", "does", "did", "and", "or", "but", "to", "of", "in", "on",
        "at", "for", "with", "my", "your", "me", "our", "this", "that", "be", "been",
        "being", "as", "if", "from", "by", "so", "up", "down", "out", "into", "their",
        "them", "his", "her", "hers", "ours", "yours", "too", "very"
    ]

    private static let lexicon: [LexiconEntry] = [
        .init(term: "love", meaning: "a strong feeling of affection", japaneseMeaning: "愛", profiles: [.beginner], difficulty: "beginner", reason: "洋楽で頻出する基本語です。", isPhrase: false),
        .init(term: "dream", meaning: "a hope or image in your mind", japaneseMeaning: "夢", profiles: [.beginner], difficulty: "beginner", reason: "歌詞のイメージをつかみやすい基本語です。", isPhrase: false),
        .init(term: "light", meaning: "brightness that lets you see", japaneseMeaning: "光", profiles: [.beginner], difficulty: "beginner", reason: "比喩でもよく使われる基本語です。", isPhrase: false),
        .init(term: "lonely", meaning: "feeling sad because you are alone", japaneseMeaning: "孤独な", profiles: [.beginner, .intermediate], difficulty: "beginner", reason: "感情表現として覚えやすい単語です。", isPhrase: false),
        .init(term: "hold on", meaning: "wait or remain strong", japaneseMeaning: "踏ん張る / 待つ", profiles: [.dailyConversation, .musicUnderstanding], difficulty: "daily", reason: "会話でも歌詞でもよく出る句動詞です。", isPhrase: true),
        .init(term: "let go", meaning: "stop holding or release emotionally", japaneseMeaning: "手放す", profiles: [.dailyConversation, .musicUnderstanding], difficulty: "daily", reason: "感情表現としてよく使われます。", isPhrase: true),
        .init(term: "come back", meaning: "return to someone or somewhere", japaneseMeaning: "戻る", profiles: [.dailyConversation, .musicUnderstanding], difficulty: "daily", reason: "日常会話でも歌詞でも頻出です。", isPhrase: true),
        .init(term: "figure out", meaning: "understand or solve something", japaneseMeaning: "理解する / 解決する", profiles: [.dailyConversation, .advancedAcademic], difficulty: "daily", reason: "会話に直結する重要表現です。", isPhrase: true),
        .init(term: "move on", meaning: "continue after a difficult event", japaneseMeaning: "前に進む", profiles: [.dailyConversation, .musicUnderstanding], difficulty: "daily", reason: "恋愛や別れの歌詞で頻出します。", isPhrase: true),
        .init(term: "fade away", meaning: "gradually disappear", japaneseMeaning: "消えていく", profiles: [.musicUnderstanding, .advancedAcademic], difficulty: "music", reason: "洋楽の歌詞でよく使われる印象的な表現です。", isPhrase: true),
        .init(term: "break down", meaning: "collapse emotionally or physically", japaneseMeaning: "崩れる / 取り乱す", profiles: [.musicUnderstanding, .dailyConversation], difficulty: "music", reason: "感情の揺れを表す頻出表現です。", isPhrase: true),
        .init(term: "fall apart", meaning: "break into pieces or emotionally collapse", japaneseMeaning: "ばらばらになる / 崩壊する", profiles: [.musicUnderstanding, .advancedAcademic], difficulty: "music", reason: "歌詞の核心をつかみやすい句動詞です。", isPhrase: true),
        .init(term: "give up", meaning: "stop trying", japaneseMeaning: "諦める", profiles: [.dailyConversation, .musicUnderstanding], difficulty: "daily", reason: "会話でも歌詞でもよく出る表現です。", isPhrase: true),
        .init(term: "fragile", meaning: "easily broken emotionally or physically", japaneseMeaning: "壊れやすい / もろい", profiles: [.advancedAcademic], difficulty: "advanced-academic", reason: "英検準1級レベルの感情語彙です。", isPhrase: false),
        .init(term: "pretend", meaning: "act as if something is true", japaneseMeaning: "ふりをする", profiles: [.advancedAcademic, .intermediate], difficulty: "advanced-academic", reason: "歌詞の心情理解に役立つ語です。", isPhrase: false),
        .init(term: "regret", meaning: "feel sorry about something done", japaneseMeaning: "後悔", profiles: [.advancedAcademic], difficulty: "advanced-academic", reason: "抽象的な感情語彙として重要です。", isPhrase: false),
        .init(term: "desire", meaning: "a strong wish", japaneseMeaning: "願望", profiles: [.advancedAcademic, .sat], difficulty: "advanced-academic", reason: "抽象語として読解力を伸ばせます。", isPhrase: false),
        .init(term: "silence", meaning: "complete absence of sound", japaneseMeaning: "沈黙", profiles: [.advancedAcademic, .musicUnderstanding], difficulty: "advanced-academic", reason: "歌詞で象徴的に使われやすい語です。", isPhrase: false),
        .init(term: "gravity", meaning: "a serious or heavy force", japaneseMeaning: "重力 / 深刻さ", profiles: [.advancedAcademic, .sat], difficulty: "advanced-academic", reason: "比喩理解にもつながる語です。", isPhrase: false),
        .init(term: "obscure", meaning: "not clear or difficult to understand", japaneseMeaning: "不明瞭な", profiles: [.veryAdvanced, .sat], difficulty: "very-advanced", reason: "上級読解で役立つ難語です。", isPhrase: false),
        .init(term: "solitude", meaning: "the state of being alone", japaneseMeaning: "孤独", profiles: [.veryAdvanced, .sat], difficulty: "very-advanced", reason: "文学的な抽象語として価値があります。", isPhrase: false),
        .init(term: "surrender", meaning: "stop resisting and give in", japaneseMeaning: "降伏する / 身を委ねる", profiles: [.veryAdvanced, .musicUnderstanding], difficulty: "very-advanced", reason: "歌詞の感情変化を読み取りやすい語です。", isPhrase: false),
        .init(term: "resilient", meaning: "able to recover quickly", japaneseMeaning: "立ち直る力がある", profiles: [.veryAdvanced, .toefl], difficulty: "very-advanced", reason: "上級語彙として実用性があります。", isPhrase: false),
        .init(term: "illusion", meaning: "a false idea or appearance", japaneseMeaning: "幻想", profiles: [.veryAdvanced, .sat], difficulty: "very-advanced", reason: "評論や文学にもつながる語です。", isPhrase: false),
        .init(term: "impact", meaning: "a strong effect or influence", japaneseMeaning: "影響", profiles: [.toefl], difficulty: "toefl", reason: "TOEFLで頻出する学術語彙です。", isPhrase: false),
        .init(term: "environment", meaning: "the natural world or surrounding conditions", japaneseMeaning: "環境", profiles: [.toefl], difficulty: "toefl", reason: "学術トピックで頻出します。", isPhrase: false),
        .init(term: "behavior", meaning: "the way someone acts", japaneseMeaning: "行動", profiles: [.toefl], difficulty: "toefl", reason: "社会科学系の語彙として重要です。", isPhrase: false),
        .init(term: "influence", meaning: "the power to affect something", japaneseMeaning: "影響を与える", profiles: [.toefl], difficulty: "toefl", reason: "論理的な説明に使いやすい語です。", isPhrase: false),
        .init(term: "structure", meaning: "the arrangement of parts", japaneseMeaning: "構造", profiles: [.toefl], difficulty: "toefl", reason: "アカデミック英語での汎用性が高い語です。", isPhrase: false),
        .init(term: "ambiguous", meaning: "having more than one possible meaning", japaneseMeaning: "曖昧な", profiles: [.sat], difficulty: "sat", reason: "SATや読解問題でよく扱われる語です。", isPhrase: false),
        .init(term: "inevitable", meaning: "certain to happen", japaneseMeaning: "避けられない", profiles: [.sat, .veryAdvanced], difficulty: "sat", reason: "抽象的で論理的な文脈に強い語です。", isPhrase: false),
        .init(term: "profound", meaning: "very deep or serious", japaneseMeaning: "深い / 奥深い", profiles: [.sat], difficulty: "sat", reason: "文学的な感想表現に使える語です。", isPhrase: false),
        .init(term: "diminish", meaning: "become or make smaller", japaneseMeaning: "減少する", profiles: [.sat, .toefl], difficulty: "sat", reason: "抽象的変化を表す上級語です。", isPhrase: false),
        .init(term: "contradict", meaning: "say the opposite of something", japaneseMeaning: "矛盾する", profiles: [.sat], difficulty: "sat", reason: "論理展開を読む力につながります。", isPhrase: false)
    ]

    func extractKeywords(
        from lyrics: String,
        goalText: String,
        songTitle: String,
        artistName: String
    ) async throws -> [ExtractedKeyword] {
        let trimmedLyrics = lyrics.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLyrics.isEmpty else { return [] }

        let profile = GoalLevelInterpreter.inferKeywordProfile(from: goalText)
        let lines = trimmedLyrics
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var results: [ExtractedKeyword] = []
        var seenTerms = Set<String>()

        for entry in Self.lexicon where entry.profiles.contains(profile) {
            guard let sourceLine = matchedLine(for: entry.term, in: lines, isPhrase: entry.isPhrase) else { continue }
            let key = normalizedToken(entry.term)
            guard seenTerms.insert(key).inserted else { continue }
            results.append(
                ExtractedKeyword(
                    id: UUID(),
                    word: entry.term,
                    meaning: entry.meaning,
                    japaneseMeaning: entry.japaneseMeaning,
                    sourceLine: sourceLine,
                    songTitle: songTitle,
                    artistName: artistName,
                    goalText: goalText,
                    difficulty: entry.difficulty,
                    reason: entry.reason,
                    createdAt: Date()
                )
            )
        }

        if results.count < 10 {
            let fallbacks = fallbackKeywords(from: lines, profile: profile, goalText: goalText, songTitle: songTitle, artistName: artistName, seenTerms: seenTerms)
            results.append(contentsOf: fallbacks)
        }

        return Array(results.prefix(12))
    }

    private func matchedLine(for term: String, in lines: [String], isPhrase: Bool) -> String? {
        let needle = normalizedToken(term)
        return lines.first { line in
            let normalizedLine = normalizedText(line)
            if isPhrase {
                return normalizedLine.contains(needle)
            }
            return normalizedLine.split(separator: " ").contains(Substring(needle))
        }
    }

    private func fallbackKeywords(
        from lines: [String],
        profile: KeywordProfile,
        goalText: String,
        songTitle: String,
        artistName: String,
        seenTerms: Set<String>
    ) -> [ExtractedKeyword] {
        var results: [ExtractedKeyword] = []
        var mutableSeen = seenTerms

        for line in lines {
            let normalizedLine = normalizedText(line)
            let tokens = normalizedLine.split(separator: " ").map(String.init)
            for token in tokens {
                guard shouldIncludeFallbackToken(token, for: profile) else { continue }
                guard mutableSeen.insert(token).inserted else { continue }
                results.append(
                    ExtractedKeyword(
                        id: UUID(),
                        word: token,
                        meaning: fallbackMeaning(for: token),
                        japaneseMeaning: fallbackJapaneseMeaning(for: token, profile: profile),
                        sourceLine: line,
                        songTitle: songTitle,
                        artistName: artistName,
                        goalText: goalText,
                        difficulty: profile.difficultyLabel,
                        reason: profile.defaultReason,
                        createdAt: Date()
                    )
                )
                if results.count >= 6 {
                    return results
                }
            }
        }
        return results
    }

    private func shouldIncludeFallbackToken(_ token: String, for profile: KeywordProfile) -> Bool {
        guard !token.isEmpty,
              !Self.stopWords.contains(token),
              token.rangeOfCharacter(from: CharacterSet.letters.inverted) == nil else {
            return false
        }

        switch profile {
        case .beginner:
            return (4...6).contains(token.count)
        case .dailyConversation, .musicUnderstanding:
            return (5...9).contains(token.count)
        case .intermediate:
            return token.count >= 6
        case .advancedAcademic, .toefl:
            return token.count >= 7
        case .veryAdvanced, .sat:
            return token.count >= 8
        }
    }

    private func fallbackMeaning(for token: String) -> String {
        token.replacingOccurrences(of: "_", with: " ")
    }

    private func fallbackJapaneseMeaning(for token: String, profile: KeywordProfile) -> String {
        switch profile {
        case .beginner:
            return "歌詞の基本単語"
        case .dailyConversation:
            return "会話で使いやすい表現"
        case .intermediate:
            return "中級学習向けの単語"
        case .advancedAcademic:
            return "英検準1級向けの語彙"
        case .veryAdvanced:
            return "上級学習向けの難語"
        case .toefl:
            return "TOEFL向け学術語彙"
        case .sat:
            return "SAT向け抽象語彙"
        case .musicUnderstanding:
            return "洋楽理解に役立つ表現"
        }
    }

    private func normalizedText(_ text: String) -> String {
        text.lowercased()
            .unicodeScalars
            .map { scalar in
                CharacterSet.alphanumerics.contains(scalar) || CharacterSet.whitespaces.contains(scalar) ? Character(scalar) : " "
            }
            .reduce(into: "") { partialResult, character in
                partialResult.append(character)
            }
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizedToken(_ text: String) -> String {
        normalizedText(text)
    }
}

final class OpenAIKeywordExtractor: KeywordExtracting {
    func extractKeywords(
        from lyrics: String,
        goalText: String,
        songTitle: String,
        artistName: String
    ) async throws -> [ExtractedKeyword] {
        // You are an English vocabulary tutor for Japanese learners.
        //
        // The user goal is:
        // {goalText}
        //
        // Extract 5 to 12 useful English words or phrases from the song lyrics below.
        //
        // Rules:
        // - Match the vocabulary to the user's goal.
        // - Prefer useful words, phrases, phrasal verbs, idioms, and emotional expressions.
        // - Avoid very basic words unless the user is beginner.
        // - Avoid duplicates.
        // - Include the original lyric line.
        // - Explain why each item is useful for this user's goal.
        // - Return JSON only.
        //
        // JSON format:
        // [
        //   {
        //     "word": "...",
        //     "meaning": "...",
        //     "japaneseMeaning": "...",
        //     "sourceLine": "...",
        //     "difficulty": "...",
        //     "reason": "..."
        //   }
        // ]
        //
        // Lyrics:
        // {lyrics}
        _ = (lyrics, goalText, songTitle, artistName)
        return []
    }
}
