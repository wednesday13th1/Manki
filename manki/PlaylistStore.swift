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

    @discardableResult
    func saveAppleMusicPlaylist(id appleMusicPlaylistID: String,
                                name: String,
                                songs: [MankiSong]) -> MankiPlaylist {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedSongs = songs.map { song in
            guard let appleMusicID = song.appleMusicID, !appleMusicID.isEmpty else {
                return song
            }
            return MankiSong(
                id: appleMusicID,
                title: song.title,
                artist: song.artist,
                appleMusicID: appleMusicID,
                albumTitle: song.albumTitle,
                artworkURL: song.artworkURL,
                lyricsID: song.lyricsID,
                mood: song.mood,
                level: song.level,
                keywords: song.keywords,
                lyricsLines: song.lyricsLines,
                previewURL: song.previewURL,
                timedLyrics: song.timedLyrics
            )
        }

        var playlists = getPlaylists()
        let playlist: MankiPlaylist

        if let index = playlists.firstIndex(where: { $0.appleMusicPlaylistID == appleMusicPlaylistID }) {
            playlists[index].name = trimmedName.isEmpty ? playlists[index].name : trimmedName
            playlists[index].songs = normalizedSongs
            playlists[index].type = .appleMusic
            playlists[index].appleMusicPlaylistID = appleMusicPlaylistID
            playlist = playlists[index]
        } else {
            let newPlaylist = MankiPlaylist(
                name: trimmedName.isEmpty ? "Apple Music Playlist" : trimmedName,
                songs: normalizedSongs,
                type: .appleMusic,
                appleMusicPlaylistID: appleMusicPlaylistID
            )
            playlists.insert(newPlaylist, at: 0)
            playlist = newPlaylist
        }

        savePlaylists(playlists)
        return playlist
    }

    func addSong(_ song: MankiSong, to playlistID: UUID) -> AddSongResult {
        var playlists = getPlaylists()
        guard let index = playlists.firstIndex(where: { $0.id == playlistID }) else {
            return .playlistNotFound
        }

        let normalizedSong = normalizedSongForStorage(song)

        if let appleMusicID = normalizedSong.appleMusicID, !appleMusicID.isEmpty,
           playlists[index].songs.contains(where: { $0.appleMusicID == appleMusicID }) {
            return .duplicate
        }

        if playlists[index].songs.contains(where: { $0.id == normalizedSong.id }) {
            return .duplicate
        }

        playlists[index].songs.append(normalizedSong)
        savePlaylists(playlists)
        return .added(playlists[index])
    }

    private func normalizedSongForStorage(_ song: MankiSong) -> MankiSong {
        guard let appleMusicID = song.appleMusicID, !appleMusicID.isEmpty else {
            return song
        }

        return MankiSong(
            id: appleMusicID,
            title: song.title,
            artist: song.artist,
            appleMusicID: appleMusicID,
            albumTitle: song.albumTitle,
            artworkURL: song.artworkURL,
            lyricsID: song.lyricsID,
            mood: song.mood,
            level: song.level,
            keywords: song.keywords,
            lyricsLines: song.lyricsLines,
            previewURL: song.previewURL,
            timedLyrics: song.timedLyrics
        )
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

enum AddSongResult {
    case added(MankiPlaylist)
    case duplicate
    case playlistNotFound
}
