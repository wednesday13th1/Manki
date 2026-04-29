import Foundation
import MusicKit

struct TimedLyricLine: Codable, Hashable {
    let time: TimeInterval
    let text: String
    let japaneseTranslation: String
}

struct MankiSong: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let title: String
    let artist: String
    let appleMusicID: String?
    let albumTitle: String?
    let artworkURL: URL?
    let lyricsID: String
    let mood: String
    let level: String
    let keywords: [MankiKeyword]
    let lyricsLines: [String]
    let previewURL: URL?
    let timedLyrics: [TimedLyricLine]

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case artist
        case appleMusicID
        case albumTitle
        case artworkURL
        case lyricsID
        case mood
        case level
        case keywords
        case lyricsLines
        case previewURL
        case timedLyrics
    }

    init(id: String = UUID().uuidString,
         title: String,
         artist: String,
         appleMusicID: String? = nil,
         albumTitle: String? = nil,
         artworkURL: URL? = nil,
         lyricsID: String? = nil,
         mood: String,
         level: String,
         keywords: [MankiKeyword],
         lyricsLines: [String],
         previewURL: URL?,
         timedLyrics: [TimedLyricLine]) {
        self.id = id
        self.title = title
        self.artist = artist
        self.appleMusicID = appleMusicID
        self.albumTitle = albumTitle
        self.artworkURL = artworkURL
        self.lyricsID = lyricsID ?? appleMusicID ?? id
        self.mood = mood
        self.level = level
        self.keywords = keywords
        self.lyricsLines = lyricsLines
        self.previewURL = previewURL
        self.timedLyrics = timedLyrics
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedAppleMusicID = try container.decodeIfPresent(String.self, forKey: .appleMusicID)
        id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? decodedAppleMusicID
            ?? UUID().uuidString
        title = try container.decode(String.self, forKey: .title)
        artist = try container.decode(String.self, forKey: .artist)
        appleMusicID = decodedAppleMusicID
        albumTitle = try container.decodeIfPresent(String.self, forKey: .albumTitle)
        artworkURL = try container.decodeIfPresent(URL.self, forKey: .artworkURL)
        lyricsID = try container.decodeIfPresent(String.self, forKey: .lyricsID)
            ?? decodedAppleMusicID
            ?? id
        mood = try container.decode(String.self, forKey: .mood)
        level = try container.decode(String.self, forKey: .level)
        keywords = try container.decode([MankiKeyword].self, forKey: .keywords)
        lyricsLines = try container.decode([String].self, forKey: .lyricsLines)
        previewURL = try container.decodeIfPresent(URL.self, forKey: .previewURL)
        timedLyrics = try container.decodeIfPresent([TimedLyricLine].self, forKey: .timedLyrics) ?? []
    }
}

@available(iOS 15.0, *)
extension MankiSong {
    init(from song: Song) {
        self.init(
            id: song.id.rawValue,
            title: song.title,
            artist: song.artistName,
            appleMusicID: song.id.rawValue,
            albumTitle: song.albumTitle,
            artworkURL: song.artwork?.url(width: 300, height: 300),
            lyricsID: song.id.rawValue,
            mood: "apple music",
            level: "music",
            keywords: [],
            lyricsLines: [],
            previewURL: song.previewAssets?.first?.url,
            timedLyrics: []
        )
    }
}

enum PlaylistType: String, Codable, Hashable {
    case aiRecommended
    case userCreated
    case appleMusic

    var displayName: String {
        switch self {
        case .aiRecommended:
            return "AI"
        case .userCreated:
            return "MY"
        case .appleMusic:
            return "APPLE"
        }
    }
}

struct MankiPlaylist: Codable, Hashable {
    let id: UUID
    var name: String
    var songs: [MankiSong]
    var type: PlaylistType
    var appleMusicPlaylistID: String?

    init(id: UUID = UUID(),
         name: String,
         songs: [MankiSong],
         type: PlaylistType,
         appleMusicPlaylistID: String? = nil) {
        self.id = id
        self.name = name
        self.songs = songs
        self.type = type
        self.appleMusicPlaylistID = appleMusicPlaylistID
    }

    var title: String {
        name
    }

    var subtitle: String {
        switch type {
        case .aiRecommended:
            return "AIおすすめ"
        case .userCreated:
            return "ローカル保存"
        case .appleMusic:
            return "Apple Music mock"
        }
    }
}
