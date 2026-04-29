import Foundation
import AVFoundation
import MusicKit

@available(iOS 15.0, *)
struct AppleMusicPlaylistSnapshot: Hashable {
    let playlist: MusicKit.Playlist
    let songs: [Song]

    var id: String { playlist.id.rawValue }
    var title: String { playlist.name }
    var artworkURL: URL? { playlist.artwork?.url(width: 200, height: 200) }
    var songCount: Int { songs.count }
}

@MainActor
final class MusicService {
    static let shared = MusicService()

    struct PermissionState {
        let granted: Bool
        let message: String
    }

    struct AppleMusicPlaylistSummary {
        let title: String
    }

    private var player: AVPlayer?
    private var fallbackStartDate: Date?
    private var isFallbackPlaying = false
    private var fallbackPlaybackTime: TimeInterval = 0
    private var currentSongID: String?
    private init() {}

    func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("AudioSession error:", error)
        }
    }

    func requestAppleMusicPermissionState() async -> PermissionState {
        if #available(iOS 15.0, *), await requestAppleMusicPermission() {
            return PermissionState(
                granted: true,
                message: "Apple Music ライブラリへのアクセスが許可されました。実機での動作確認を推奨します。"
            )
        }
        return PermissionState(
            granted: false,
            message: "Apple Musicへのアクセスが許可されていません。設定から許可してください。"
        )
    }

    func playPreview(url: URL, songID: String) {
        stop()
        configureAudioSession()
        currentSongID = songID
        fallbackStartDate = Date().addingTimeInterval(-fallbackPlaybackTime)
        isFallbackPlaying = true
        player = AVPlayer(url: url)
        player?.play()
    }

    func pause() {
        player?.pause()
        if #available(iOS 15.0, *) {
            ApplicationMusicPlayer.shared.pause()
        }
        if isFallbackPlaying {
            fallbackPlaybackTime = currentPlaybackTime()
            isFallbackPlaying = false
        }
    }

    func playSong(_ song: MankiSong) {
        print("Now playing:", song.id, song.title, song.artist, song.previewURL?.absoluteString ?? "no previewURL")
        if #available(iOS 15.0, *), let appleMusicID = song.appleMusicID {
            Task { [weak self] in
                _ = await self?.playAppleMusicSongByID(appleMusicID, expectedSongID: song.id)
            }
            return
        }
        if let previewURL = song.previewURL {
            playPreview(url: previewURL, songID: song.id)
            return
        }
        stop()
        currentSongID = song.id
        fallbackStartDate = Date().addingTimeInterval(-fallbackPlaybackTime)
        isFallbackPlaying = true
    }

    func pauseSong() {
        pause()
    }

    func currentPlaybackTime() -> TimeInterval {
        if let player {
            let seconds = player.currentTime().seconds
            return seconds.isFinite ? seconds : 0
        }
        guard isFallbackPlaying, let fallbackStartDate else { return fallbackPlaybackTime }
        return max(0, Date().timeIntervalSince(fallbackStartDate))
    }

    func seek(to time: TimeInterval) {
        let clampedTime = max(0, time)
        if let player {
            let target = CMTime(seconds: clampedTime, preferredTimescale: 600)
            player.seek(to: target)
        } else {
            fallbackPlaybackTime = clampedTime
            fallbackStartDate = Date().addingTimeInterval(-fallbackPlaybackTime)
        }
    }

    func stop() {
        player?.pause()
        player = nil
        if #available(iOS 15.0, *) {
            ApplicationMusicPlayer.shared.pause()
            ApplicationMusicPlayer.shared.stop()
        }
        isFallbackPlaying = false
        fallbackPlaybackTime = 0
        fallbackStartDate = nil
        currentSongID = nil
    }

    func stopPlayback() {
        stop()
    }

    @MainActor
    func loadAppleMusicPlaylistSummaries() async -> [AppleMusicPlaylistSummary] {
        if #available(iOS 15.0, *), await requestAppleMusicPermission() {
            let playlists = await fetchUserPlaylists()
            return playlists.map { AppleMusicPlaylistSummary(title: $0.name) }
        }
        return []
    }

    @available(iOS 15.0, *)
    func requestAppleMusicPermission() async -> Bool {
        let status = await MusicAuthorization.request()
        return status == .authorized
    }

    @available(iOS 15.0, *)
    func checkAuthorizationStatus() -> MusicAuthorization.Status {
        MusicAuthorization.currentStatus
    }

    @available(iOS 15.0, *)
    func fetchUserPlaylists() async -> [MusicKit.Playlist] {
        do {
            var request = MusicLibraryRequest<MusicKit.Playlist>()
            request.limit = 25
            let response = try await request.response()
            return Array(response.items)
        } catch {
            print("Failed to fetch playlists:", error)
            return []
        }
    }

    @available(iOS 15.0, *)
    func fetchAppleMusicSongByID(_ id: String) async -> Song? {
        do {
            let musicID = MusicItemID(rawValue: id)
            let request = MusicCatalogResourceRequest<Song>(
                matching: \.id,
                equalTo: musicID
            )
            let response = try await request.response()
            return response.items.first
        } catch {
            print("Failed to fetch Apple Music song by ID:", id, error)
            return nil
        }
    }

    @available(iOS 15.0, *)
    func fetchDetailedUserPlaylists() async -> [AppleMusicPlaylistSnapshot] {
        let playlists = await fetchUserPlaylists()
        var snapshots: [AppleMusicPlaylistSnapshot] = []
        for playlist in playlists {
            let songs = await fetchSongs(from: playlist)
            snapshots.append(AppleMusicPlaylistSnapshot(playlist: playlist, songs: songs))
        }
        return snapshots
    }

    @available(iOS 15.0, *)
    func fetchSongs(from playlist: MusicKit.Playlist) async -> [Song] {
        do {
            let detailedPlaylist = try await playlist.with([.tracks])
            guard let tracks = detailedPlaylist.tracks else {
                return []
            }
            return tracks.compactMap { track in
                if case .song(let song) = track {
                    return song
                }
                return nil
            }
        } catch {
            print("Failed to fetch songs from playlist:", error)
            return []
        }
    }

    @available(iOS 15.0, *)
    @discardableResult
    func playAppleMusicSong(_ song: Song) async -> Bool {
        await playAppleMusicSong(song, expectedSongID: song.id.rawValue)
    }

    @available(iOS 15.0, *)
    @discardableResult
    func playAppleMusicSong(_ song: Song, expectedSongID: String) async -> Bool {
        do {
            stop()
            // Apple Music library access and playback should be tested on a real device.
            // Make sure the device is signed into Apple Music and has permission enabled.
            currentSongID = expectedSongID
            fallbackStartDate = Date()
            fallbackPlaybackTime = 0
            isFallbackPlaying = true
            ApplicationMusicPlayer.shared.queue = .init(for: [song], startingAt: song)
            try await ApplicationMusicPlayer.shared.play()
            print("Playing Apple Music song:", song.title, song.artistName)
            return true
        } catch {
            print("Failed to play Apple Music song:", error)
            stop()
            return false
        }
    }

    @available(iOS 15.0, *)
    @discardableResult
    func playAppleMusicSongByID(_ songID: String) async -> Bool {
        await playAppleMusicSongByID(songID, expectedSongID: songID)
    }

    @available(iOS 15.0, *)
    @discardableResult
    func playAppleMusicSongByID(_ songID: String, expectedSongID: String) async -> Bool {
        guard let song = await fetchAppleMusicSongByID(songID) else {
            print("No Apple Music song found for id:", songID)
            return false
        }
        return await playAppleMusicSong(song, expectedSongID: expectedSongID)
    }

    @available(iOS 15.0, *)
    func pauseAppleMusic() {
        ApplicationMusicPlayer.shared.pause()
        if isFallbackPlaying {
            fallbackPlaybackTime = currentPlaybackTime()
            isFallbackPlaying = false
        }
    }

    @available(iOS 15.0, *)
    func stopAppleMusic() {
        ApplicationMusicPlayer.shared.stop()
        isFallbackPlaying = false
        fallbackPlaybackTime = 0
        fallbackStartDate = nil
        currentSongID = nil
    }
}

enum MusicMockData {
    static let samplePreviewURL = URL(string: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3")

    static let aiRecommendedSongs: [MankiSong] = [
        MankiSong(
            id: "c8c0d4c0-8ab0-4861-a8cb-67d98a617f10",
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
            ],
            previewURL: samplePreviewURL,
            timedLyrics: [
                TimedLyricLine(time: 0.0, text: "A bright little feeling starts to glow tonight.", japaneseTranslation: "今夜、明るい気持ちが少しずつ光り始める。"),
                TimedLyricLine(time: 3.5, text: "Your soft words stay with me on the ride home.", japaneseTranslation: "やわらかな言葉が帰り道でも残っている。"),
                TimedLyricLine(time: 7.0, text: "Every color turns warm in this small moment.", japaneseTranslation: "この小さな瞬間で、景色の色があたたかく変わる。")
            ]
        ),
        MankiSong(
            id: "14c5058c-e415-4d66-a415-3bb596f2c7c7",
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
            ],
            previewURL: samplePreviewURL,
            timedLyrics: [
                TimedLyricLine(time: 0.0, text: "I find a rhythm when the room gets loud.", japaneseTranslation: "部屋がにぎやかになると、自分のリズムが見つかる。"),
                TimedLyricLine(time: 3.5, text: "You can ignore the static and move ahead.", japaneseTranslation: "ノイズは気にせず、そのまま前へ進めばいい。"),
                TimedLyricLine(time: 7.0, text: "My heart starts to bounce with the beat.", japaneseTranslation: "鼓動がビートに合わせて弾み始める。")
            ]
        ),
        MankiSong(
            id: "85691417-a768-4b1f-b6af-34d2cbcfec09",
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
            ],
            previewURL: samplePreviewURL,
            timedLyrics: [
                TimedLyricLine(time: 0.0, text: "A dream stays awake above the ceiling.", japaneseTranslation: "夢は天井の向こうでまだ目を覚ましている。"),
                TimedLyricLine(time: 3.5, text: "Tiny lights blink while I drop my doubt.", japaneseTranslation: "迷いを手放すたび、小さな光がまたたく。"),
                TimedLyricLine(time: 7.0, text: "The night feels wide when hopes gather.", japaneseTranslation: "希望が集まると、夜はもっと広く感じられる。")
            ]
        )
    ]

    static let applePlaylistSongs: [MankiSong] = [
        MankiSong(
            id: "68d019cb-619c-4fa6-8ee2-60d30ba1f751",
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
            ],
            previewURL: samplePreviewURL,
            timedLyrics: [
                TimedLyricLine(time: 0.0, text: "Neon shadows move when the city wakes.", japaneseTranslation: "街が目を覚ますと、ネオンの影が動き出す。"),
                TimedLyricLine(time: 3.5, text: "I hurry through the avenue alone.", japaneseTranslation: "ひとりで通りを急ぎ足で進んでいく。"),
                TimedLyricLine(time: 7.0, text: "The road looks empty but the lights keep calling.", japaneseTranslation: "道は静かでも、光はまだこちらを呼んでいる。")
            ]
        ),
        MankiSong(
            id: "f37a8b87-2f40-44a9-a8f0-96b7d508f9a1",
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
            ],
            previewURL: samplePreviewURL,
            timedLyrics: [
                TimedLyricLine(time: 0.0, text: "I float a little higher with each chorus.", japaneseTranslation: "サビのたびに、気持ちが少し高く浮かび上がる。"),
                TimedLyricLine(time: 3.5, text: "A spark appears when the room starts smiling.", japaneseTranslation: "部屋に笑顔が広がると、小さなきらめきが生まれる。"),
                TimedLyricLine(time: 7.0, text: "We find a groove and hold onto it.", japaneseTranslation: "ちょうどいいノリを見つけて、そのままつかんでいく。")
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
        songs.removeAll { $0.id == song.id }
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
