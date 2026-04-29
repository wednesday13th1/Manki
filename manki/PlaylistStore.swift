import Foundation

final class MusicPlaylistStore {
    static let shared = MusicPlaylistStore()

    private let storageKey = "manki.music.user.playlists"
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    private init() {}

    @discardableResult
    func createPlaylist(name: String) -> MankiPlaylist {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let playlist = MankiPlaylist(
            name: trimmedName.isEmpty ? "New Playlist" : trimmedName,
            songs: [],
            type: .userCreated
        )
        var playlists = getPlaylists()
        playlists.insert(playlist, at: 0)
        savePlaylists(playlists)
        return playlist
    }

    func getPlaylists() -> [MankiPlaylist] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let playlists = try? decoder.decode([MankiPlaylist].self, from: data) else {
            return []
        }
        return playlists
    }

    private func savePlaylists(_ playlists: [MankiPlaylist]) {
        guard let data = try? encoder.encode(playlists) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
