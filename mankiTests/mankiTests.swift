//
//  mankiTests.swift
//  mankiTests
//
//  Created by 井上　希稟 on 2025/12/26.
//

import Testing
@testable import manki

struct mankiTests {

    @Test func importParser_skipsIndexAndIPA_buildsPairs() async throws {
        let text = """
        0963
        patriot
        [péitriat]
        愛国者
        0964
        legislature
        [lédʒəsleitʃər]
        議会、立法府
        """

        let rows = ImportParser.parse(text: text, mode: .auto)
        let resolved = rows.filter { $0.isResolved }

        #expect(resolved.count >= 2)
        #expect(resolved.contains { $0.term.lowercased() == "patriot" && $0.meaning.contains("愛国者") })
        #expect(resolved.contains { $0.term.lowercased() == "legislature" && $0.meaning.contains("議会") })
    }

    @Test func importParser_doesNotPairEnglishOnlyLines() async throws {
        let text = """
        patriot
        legislature
        inflammation
        """
        let rows = ImportParser.parse(text: text, mode: .alternating)
        #expect(rows.allSatisfy { !$0.isResolved })
    }

    @Test func musicPlaylistStore_savesAppleMusicSongsWithAppleMusicID() async throws {
        UserDefaults.standard.removeObject(forKey: "manki.music.user.playlists")

        let song = MankiSong(
            id: "temporary-id",
            title: "Test Song",
            artist: "Test Artist",
            appleMusicID: "apple-song-123",
            albumTitle: "Album",
            artworkURL: URL(string: "https://example.com/artwork.jpg"),
            lyricsID: "apple-song-123",
            mood: "apple music",
            level: "music",
            keywords: [],
            lyricsLines: [],
            previewURL: URL(string: "https://example.com/preview.m4a"),
            timedLyrics: []
        )

        let savedPlaylist = MusicPlaylistStore.shared.saveAppleMusicPlaylist(
            id: "playlist-1",
            name: "Imported",
            songs: [song]
        )

        #expect(savedPlaylist.type == .appleMusic)
        #expect(savedPlaylist.appleMusicPlaylistID == "playlist-1")
        #expect(savedPlaylist.songs.count == 1)
        #expect(savedPlaylist.songs[0].appleMusicID == "apple-song-123")
        #expect(savedPlaylist.songs[0].id == "apple-song-123")
    }

    @Test func musicPlaylistStore_updatesExistingAppleMusicPlaylistByPlaylistID() async throws {
        UserDefaults.standard.removeObject(forKey: "manki.music.user.playlists")

        let firstSong = MankiSong(
            id: "first",
            title: "First",
            artist: "Artist",
            appleMusicID: "song-1",
            albumTitle: nil,
            artworkURL: nil,
            lyricsID: "song-1",
            mood: "apple music",
            level: "music",
            keywords: [],
            lyricsLines: [],
            previewURL: nil,
            timedLyrics: []
        )
        let secondSong = MankiSong(
            id: "second",
            title: "Second",
            artist: "Artist",
            appleMusicID: "song-2",
            albumTitle: nil,
            artworkURL: nil,
            lyricsID: "song-2",
            mood: "apple music",
            level: "music",
            keywords: [],
            lyricsLines: [],
            previewURL: nil,
            timedLyrics: []
        )

        _ = MusicPlaylistStore.shared.saveAppleMusicPlaylist(id: "playlist-1", name: "Imported", songs: [firstSong])
        let updated = MusicPlaylistStore.shared.saveAppleMusicPlaylist(id: "playlist-1", name: "Imported v2", songs: [secondSong])
        let playlists = MusicPlaylistStore.shared.getPlaylists()

        #expect(playlists.count == 1)
        #expect(updated.name == "Imported v2")
        #expect(playlists[0].songs.map(\.appleMusicID) == ["song-2"])
        #expect(playlists[0].songs.map(\.id) == ["song-2"])
    }

    @Test func keywordPicker_deduplicatesAndStoresLyricPosition() async throws {
        let lyrics = [
            TimedLyricLine(time: 0, text: "We glow when the skyline starts glowing", japaneseTranslation: ""),
            TimedLyricLine(time: 12.5, text: "Gravity keeps pulling but the skyline will glow", japaneseTranslation: ""),
            TimedLyricLine(time: 20.0, text: "Momentum carries the feeling forward", japaneseTranslation: "")
        ]

        let keywords = KeywordPicker.shared.pickKeywords(from: lyrics, level: "medium")
        let glow = try #require(keywords.first(where: { $0.word == "glow" }))

        #expect(keywords.filter { $0.word == "glow" }.count == 1)
        #expect(glow.lyricLineIndex == 1)
        #expect(glow.startTime == 12.5)
        #expect(glow.endTime == 20.0)
        #expect(glow.reason != nil)
    }

    @Test func keywordPicker_limitsKeywordCountAndFiltersStopWords() async throws {
        let lyrics = [
            TimedLyricLine(time: 0, text: "the silverfire drifting through electric motion", japaneseTranslation: ""),
            TimedLyricLine(time: 5, text: "crimsonwave echoing under midnight lanterns", japaneseTranslation: ""),
            TimedLyricLine(time: 10, text: "velvetstorm carries restless shadows onward", japaneseTranslation: ""),
            TimedLyricLine(time: 15, text: "goldenpulse breaks through silent horizons", japaneseTranslation: "")
        ]

        let keywords = KeywordPicker.shared.pickKeywords(from: lyrics, level: "advanced")

        #expect(keywords.count <= 8)
        #expect(keywords.allSatisfy { $0.word != "the" })
        #expect(keywords.allSatisfy { $0.lyricLineIndex != nil })
    }

    @Test func musicPlaylistStore_preventsDuplicateAppleMusicSongs() async throws {
        UserDefaults.standard.removeObject(forKey: "manki.music.user.playlists")

        let playlist = MusicPlaylistStore.shared.createPlaylist(name: "Favorites")
        let song = MankiSong(
            id: "temp-song",
            title: "Glow",
            artist: "Artist",
            appleMusicID: "apple-123",
            albumTitle: nil,
            artworkURL: nil,
            lyricsID: "apple-123",
            mood: "calm",
            level: "easy",
            keywords: [],
            lyricsLines: [],
            previewURL: nil,
            timedLyrics: []
        )

        let firstResult = MusicPlaylistStore.shared.addSong(song, to: playlist.id)
        let secondResult = MusicPlaylistStore.shared.addSong(song, to: playlist.id)
        let storedPlaylists = MusicPlaylistStore.shared.getPlaylists()
        let storedSong = try #require(storedPlaylists.first?.songs.first)

        if case .added = firstResult {
        } else {
            Issue.record("Expected first addSong result to be .added")
        }

        if case .duplicate = secondResult {
        } else {
            Issue.record("Expected second addSong result to be .duplicate")
        }

        #expect(storedPlaylists.first?.songs.count == 1)
        #expect(storedSong.appleMusicID == "apple-123")
        #expect(storedSong.id == "apple-123")
    }

}
