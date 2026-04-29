import Foundation
import UIKit

enum PlaylistSongSource: String, Codable {
    case manual
    case appleMusic = "apple_music"
}

enum EmotionTag: String, Codable, CaseIterable {
    case sad
    case happy
    case love
    case angry
    case calm
    case hype
    case nostalgic
    case lonely

    var displayName: String {
        rawValue.capitalized
    }

    var accentColor: UIColor {
        switch self {
        case .sad:
            return UIColor(red: 0.45, green: 0.63, blue: 0.98, alpha: 1)
        case .happy:
            return UIColor(red: 0.99, green: 0.75, blue: 0.22, alpha: 1)
        case .love:
            return UIColor(red: 0.92, green: 0.40, blue: 0.62, alpha: 1)
        case .angry:
            return UIColor(red: 0.88, green: 0.36, blue: 0.31, alpha: 1)
        case .calm:
            return UIColor(red: 0.47, green: 0.76, blue: 0.68, alpha: 1)
        case .hype:
            return UIColor(red: 0.95, green: 0.52, blue: 0.21, alpha: 1)
        case .nostalgic:
            return UIColor(red: 0.67, green: 0.57, blue: 0.86, alpha: 1)
        case .lonely:
            return UIColor(red: 0.55, green: 0.56, blue: 0.67, alpha: 1)
        }
    }
}

enum PlaylistCardDifficulty: String, Codable, CaseIterable {
    case easy
    case medium
    case hard

    var displayName: String {
        rawValue.capitalized
    }

    var mappedImportanceLevel: Int {
        switch self {
        case .easy:
            return 1
        case .medium:
            return 3
        case .hard:
            return 5
        }
    }
}

struct PlaylistCard: Codable, Identifiable {
    let id: String
    var word: String
    var meaning: String
    var examplePhrase: String
    var sourceSongTitle: String
    var emotionTag: EmotionTag
    var difficulty: PlaylistCardDifficulty
    var memo: String

    init(id: String = UUID().uuidString,
         word: String,
         meaning: String,
         examplePhrase: String,
         sourceSongTitle: String,
         emotionTag: EmotionTag,
         difficulty: PlaylistCardDifficulty,
         memo: String) {
        self.id = id
        self.word = word
        self.meaning = meaning
        self.examplePhrase = examplePhrase
        self.sourceSongTitle = sourceSongTitle
        self.emotionTag = emotionTag
        self.difficulty = difficulty
        self.memo = memo
    }

    func asSavedWord() -> SavedWord {
        SavedWord(
            english: word,
            japanese: meaning,
            exampleSentence: examplePhrase,
            illustrationScenario: nil,
            illustrationImageFileName: nil,
            isFavorite: false,
            importanceLevel: difficulty.mappedImportanceLevel,
            id: id
        )
    }
}

struct PlaylistSong: Codable, Identifiable {
    let id: String
    var title: String
    var artistName: String
    var appleMusicId: String?
    var albumTitle: String?
    var artworkUrl: String?
    var previewUrl: String?
    var duration: TimeInterval?
    var source: PlaylistSongSource
    var cards: [PlaylistCard]

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case artistName
        case artist
        case appleMusicId
        case albumTitle
        case artworkUrl
        case previewUrl
        case duration
        case source
        case cards
    }

    init(id: String = UUID().uuidString,
         title: String,
         artist: String,
         appleMusicId: String? = nil,
         albumTitle: String? = nil,
         artworkUrl: String? = nil,
         previewUrl: String? = nil,
         duration: TimeInterval? = nil,
         source: PlaylistSongSource = .manual,
         cards: [PlaylistCard] = []) {
        self.id = id
        self.title = title
        self.artistName = artist
        self.appleMusicId = appleMusicId
        self.albumTitle = albumTitle
        self.artworkUrl = artworkUrl
        self.previewUrl = previewUrl
        self.duration = duration
        self.source = source
        self.cards = cards
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        title = try container.decode(String.self, forKey: .title)
        artistName = (try? container.decode(String.self, forKey: .artistName))
            ?? (try? container.decode(String.self, forKey: .artist))
            ?? "Unknown Artist"
        appleMusicId = try container.decodeIfPresent(String.self, forKey: .appleMusicId)
        albumTitle = try container.decodeIfPresent(String.self, forKey: .albumTitle)
        artworkUrl = try container.decodeIfPresent(String.self, forKey: .artworkUrl)
        previewUrl = try container.decodeIfPresent(String.self, forKey: .previewUrl)
        duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration)
        source = try container.decodeIfPresent(PlaylistSongSource.self, forKey: .source) ?? .manual
        cards = try container.decodeIfPresent([PlaylistCard].self, forKey: .cards) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(artistName, forKey: .artistName)
        try container.encodeIfPresent(appleMusicId, forKey: .appleMusicId)
        try container.encodeIfPresent(albumTitle, forKey: .albumTitle)
        try container.encodeIfPresent(artworkUrl, forKey: .artworkUrl)
        try container.encodeIfPresent(previewUrl, forKey: .previewUrl)
        try container.encodeIfPresent(duration, forKey: .duration)
        try container.encode(source, forKey: .source)
        try container.encode(cards, forKey: .cards)
    }

    var artist: String {
        artistName
    }

    var artworkURLValue: URL? {
        artworkUrl.flatMap(URL.init(string:))
    }

    var previewURLValue: URL? {
        previewUrl.flatMap(URL.init(string:))
    }
}

struct Playlist: Codable, Identifiable {
    let id: String
    var title: String
    var description: String
    var emotionTheme: EmotionTag
    var songs: [PlaylistSong]

    init(id: String = UUID().uuidString,
         title: String,
         description: String,
         emotionTheme: EmotionTag,
         songs: [PlaylistSong] = []) {
        self.id = id
        self.title = title
        self.description = description
        self.emotionTheme = emotionTheme
        self.songs = songs
    }

    var allCards: [PlaylistCard] {
        songs.flatMap(\.cards)
    }
}

enum PlaylistStore {
    private static let fileName = "saved_playlists.json"
    private static let backupKey = "manki.saved_playlists.backup"

    static func fileURL() -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documents.appendingPathComponent(fileName)
    }

    static func loadPlaylists() -> [Playlist] {
        let url = fileURL()
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([Playlist].self, from: data) {
            return decoded
        }
        if let data = UserDefaults.standard.data(forKey: backupKey),
           let decoded = try? JSONDecoder().decode([Playlist].self, from: data) {
            if let encoded = try? JSONEncoder().encode(decoded) {
                try? encoded.write(to: url, options: .atomic)
            }
            return decoded
        }
        return []
    }

    static func savePlaylists(_ playlists: [Playlist]) {
        let url = fileURL()
        guard let data = try? JSONEncoder().encode(playlists) else { return }
        try? data.write(to: url, options: .atomic)
        UserDefaults.standard.set(data, forKey: backupKey)
    }
}

extension Playlist {
    func filteredCards(emotion: EmotionTag?, difficulty: PlaylistCardDifficulty?) -> [PlaylistCard] {
        allCards.filter { card in
            let matchesEmotion = emotion == nil || card.emotionTag == emotion
            let matchesDifficulty = difficulty == nil || card.difficulty == difficulty
            return matchesEmotion && matchesDifficulty
        }
    }
}

extension PlaylistSong {
    func filteredCards(emotion: EmotionTag?, difficulty: PlaylistCardDifficulty?) -> [PlaylistCard] {
        cards.filter { card in
            let matchesEmotion = emotion == nil || card.emotionTag == emotion
            let matchesDifficulty = difficulty == nil || card.difficulty == difficulty
            return matchesEmotion && matchesDifficulty
        }
    }
}
