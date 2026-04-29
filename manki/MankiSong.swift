import Foundation

struct MankiSong: Codable, Hashable {
    let title: String
    let artist: String
    let mood: String
    let level: String
    let keywords: [MankiKeyword]
    let lyricsLines: [String]
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

    init(id: UUID = UUID(), name: String, songs: [MankiSong], type: PlaylistType) {
        self.id = id
        self.name = name
        self.songs = songs
        self.type = type
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
