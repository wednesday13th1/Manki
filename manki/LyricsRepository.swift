import Foundation

final class LyricsRepository {
    static let shared = LyricsRepository()

    static let placeholderMessage = "この曲の歌詞はまだ準備中\n単語だけ先に拾ってみる？"

    private let lyricsByID: [String: [TimedLyricLine]] = [
        "1122782283": [
            TimedLyricLine(
                time: 0.0,
                text: "Look at the stars, look how they shine for you",
                japaneseTranslation: "星を見て、君のためにどれほど輝いているか見て"
            ),
            TimedLyricLine(
                time: 4.0,
                text: "And everything you do, yeah, they were all yellow",
                japaneseTranslation: "そして君のすることすべてが、みんな黄色く輝いていた"
            )
        ]
    ]

    private init() {}

    func lyrics(for song: MankiSong) -> [TimedLyricLine] {
        lyricsByID[song.lyricsID] ?? []
    }

    func hasLyrics(for lyricsID: String) -> Bool {
        lyricsByID[lyricsID] != nil
    }

    func hasLyrics(for song: MankiSong) -> Bool {
        hasLyrics(for: song.lyricsID) || !song.timedLyrics.isEmpty || !song.lyricsLines.isEmpty
    }

    func lyricsNotice(for song: MankiSong) -> String {
        hasLyrics(for: song)
            ? "著作権保護のため、ここでは短い歌詞行と訳のみを表示しています。"
            : Self.placeholderMessage
    }
}
