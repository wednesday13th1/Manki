import Foundation

struct MankiKeyword: Codable, Hashable {
    let word: String
    let meaning: String
    let example: String
    let difficulty: String
    let lyricLineIndex: Int?
    let startTime: TimeInterval?
    let endTime: TimeInterval?
    let reason: String?

    init(word: String,
         meaning: String,
         example: String,
         difficulty: String,
         lyricLineIndex: Int? = nil,
         startTime: TimeInterval? = nil,
         endTime: TimeInterval? = nil,
         reason: String? = nil) {
        self.word = word
        self.meaning = meaning
        self.example = example
        self.difficulty = difficulty
        self.lyricLineIndex = lyricLineIndex
        self.startTime = startTime
        self.endTime = endTime
        self.reason = reason
    }
}

extension MankiKeyword {
    func asSavedWord() -> SavedWord {
        SavedWord(
            english: word,
            japanese: meaning,
            exampleSentence: example,
            illustrationScenario: nil,
            illustrationImageFileName: nil,
            isFavorite: false,
            importanceLevel: mappedImportance()
        )
    }

    private func mappedImportance() -> Int {
        switch difficulty.lowercased() {
        case "easy":
            return 1
        case "medium":
            return 3
        case "hard":
            return 5
        default:
            return 2
        }
    }
}
