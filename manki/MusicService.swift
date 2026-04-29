import Foundation

final class MusicService {
    struct PermissionState {
        let granted: Bool
        let message: String
    }

    func requestAppleMusicPermission() async -> PermissionState {
        // ここにMusicKit連携を追加
        return PermissionState(
            granted: true,
            message: "Apple Music 連携は準備済みです。現在はモックデータで表示しています。"
        )
    }

    func fetchUserPlaylists() async -> [MankiPlaylist] {
        // ここにMusicKit連携を追加
        return [
            MankiPlaylist(
                name: "Midnight Drive",
                songs: MusicMockData.applePlaylistSongs
                    ,
                type: .appleMusic
            ),
            MankiPlaylist(
                name: "Study Pop",
                songs: Array(MusicMockData.aiRecommendedSongs.prefix(2)),
                type: .appleMusic
            )
        ]
    }

    func fetchSongsFromPlaylist(_ playlist: MankiPlaylist) async -> [MankiSong] {
        // ここにMusicKit連携を追加
        return playlist.songs
    }
}

enum MusicMockData {
    static let aiRecommendedSongs: [MankiSong] = [
        MankiSong(
            title: "Yellow",
            artist: "Coldplay",
            mood: "calm",
            level: "easy",
            keywords: [
                MankiKeyword(word: "bright", meaning: "明るい", example: "The sky feels bright today.", difficulty: "easy"),
                MankiKeyword(word: "glow", meaning: "輝く", example: "City lights glow at night.", difficulty: "medium"),
                MankiKeyword(word: "soft", meaning: "やわらかい", example: "The song has a soft mood.", difficulty: "easy")
            ],
            lyricsLines: [
                "A bright little feeling starts to glow tonight.",
                "Your soft words stay with me on the ride home.",
                "Every color turns warm in this small moment."
            ]
        ),
        MankiSong(
            title: "Shake It Off",
            artist: "Taylor Swift",
            mood: "hype",
            level: "easy",
            keywords: [
                MankiKeyword(word: "rhythm", meaning: "リズム", example: "I walk with a fast rhythm.", difficulty: "easy"),
                MankiKeyword(word: "ignore", meaning: "気にしない", example: "Ignore the noise and focus.", difficulty: "medium"),
                MankiKeyword(word: "bounce", meaning: "弾む", example: "My step starts to bounce.", difficulty: "easy")
            ],
            lyricsLines: [
                "I find a rhythm when the room gets loud.",
                "You can ignore the static and move ahead.",
                "My heart starts to bounce with the beat."
            ]
        ),
        MankiSong(
            title: "Counting Stars",
            artist: "OneRepublic",
            mood: "nostalgic",
            level: "medium",
            keywords: [
                MankiKeyword(word: "dream", meaning: "夢", example: "I dream about a better view.", difficulty: "easy"),
                MankiKeyword(word: "ceiling", meaning: "天井", example: "The light hits the ceiling.", difficulty: "medium"),
                MankiKeyword(word: "doubt", meaning: "疑い", example: "Leave your doubt outside.", difficulty: "medium")
            ],
            lyricsLines: [
                "A dream stays awake above the ceiling.",
                "Tiny lights blink while I drop my doubt.",
                "The night feels wide when hopes gather."
            ]
        )
    ]

    static let applePlaylistSongs: [MankiSong] = [
        MankiSong(
            title: "Blinding Lights",
            artist: "The Weeknd",
            mood: "hype",
            level: "medium",
            keywords: [
                MankiKeyword(word: "neon", meaning: "ネオン", example: "Neon colors fill the street.", difficulty: "medium"),
                MankiKeyword(word: "hurry", meaning: "急ぐ", example: "I hurry to catch the train.", difficulty: "easy"),
                MankiKeyword(word: "empty", meaning: "空っぽの", example: "The station feels empty.", difficulty: "easy")
            ],
            lyricsLines: [
                "Neon shadows move when the city wakes.",
                "I hurry through the avenue alone.",
                "The road looks empty but the lights keep calling."
            ]
        ),
        MankiSong(
            title: "Levitating",
            artist: "Dua Lipa",
            mood: "happy",
            level: "easy",
            keywords: [
                MankiKeyword(word: "float", meaning: "浮かぶ", example: "Clouds float over the park.", difficulty: "easy"),
                MankiKeyword(word: "spark", meaning: "きらめき", example: "A spark changed the mood.", difficulty: "medium"),
                MankiKeyword(word: "groove", meaning: "ノリ", example: "This class has a good groove.", difficulty: "medium")
            ],
            lyricsLines: [
                "I float a little higher with each chorus.",
                "A spark appears when the room starts smiling.",
                "We find a groove and hold onto it."
            ]
        )
    ]
}

enum MusicLearningStore {
    private static let recentSongsKey = "manki.music.recent.songs"
    private static let weakWordsKey = "manki.music.weak.word.ids"
    private static let storage = JsonVocabStorage()

    static func recentSongs() -> [MankiSong] {
        guard let data = UserDefaults.standard.data(forKey: recentSongsKey),
              let songs = try? JSONDecoder().decode([MankiSong].self, from: data) else {
            return []
        }
        return songs
    }

    static func saveRecent(song: MankiSong) {
        var songs = recentSongs()
        songs.removeAll { $0.title == song.title && $0.artist == song.artist }
        songs.insert(song, at: 0)
        songs = Array(songs.prefix(6))
        if let data = try? JSONEncoder().encode(songs) {
            UserDefaults.standard.set(data, forKey: recentSongsKey)
        }
    }

    static func addKeywordToWordCard(_ keyword: MankiKeyword) {
        var words = storage.loadAll()
        if let index = words.firstIndex(where: { $0.english.caseInsensitiveCompare(keyword.word) == .orderedSame }) {
            let existing = words[index]
            words[index] = SavedWord(
                english: keyword.word,
                japanese: keyword.meaning,
                exampleSentence: keyword.example,
                illustrationScenario: existing.illustrationScenario,
                illustrationImageFileName: existing.illustrationImageFileName,
                isFavorite: existing.isFavorite,
                importanceLevel: max(existing.importanceLevel, mappedImportance(for: keyword.difficulty)),
                id: existing.id
            )
        } else {
            words.append(
                SavedWord(
                    english: keyword.word,
                    japanese: keyword.meaning,
                    exampleSentence: keyword.example,
                    illustrationScenario: nil,
                    illustrationImageFileName: nil,
                    isFavorite: false,
                    importanceLevel: mappedImportance(for: keyword.difficulty)
                )
            )
        }
        storage.saveAll(words)
        print("Added keyword to word card: \(keyword.word)")
    }

    static func addKeywordToWeakWords(_ keyword: MankiKeyword) {
        var weakIDs = Set(UserDefaults.standard.stringArray(forKey: weakWordsKey) ?? [])
        let words = storage.loadAll()
        if let existing = words.first(where: { $0.english.caseInsensitiveCompare(keyword.word) == .orderedSame }) {
            weakIDs.insert(existing.id)
        } else {
            let newWord = SavedWord(
                english: keyword.word,
                japanese: keyword.meaning,
                exampleSentence: keyword.example,
                illustrationScenario: nil,
                illustrationImageFileName: nil,
                isFavorite: false,
                importanceLevel: max(mappedImportance(for: keyword.difficulty), 4)
            )
            var current = words
            current.append(newWord)
            storage.saveAll(current)
            weakIDs.insert(newWord.id)
        }
        UserDefaults.standard.set(Array(weakIDs), forKey: weakWordsKey)
        print("Added keyword to weak words: \(keyword.word)")
    }

    private static func mappedImportance(for difficulty: String) -> Int {
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

func addKeywordToWordCard(_ keyword: MankiKeyword) {
    MusicLearningStore.addKeywordToWordCard(keyword)
}

func addKeywordToWeakWords(_ keyword: MankiKeyword) {
    MusicLearningStore.addKeywordToWeakWords(keyword)
}
