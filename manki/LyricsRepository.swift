import Foundation

enum LyricsRepository {
    static let placeholderMessage = "この曲の歌詞はまだ準備中\n単語だけ先に拾ってみる？"

    static func hasLyrics(for song: MankiSong) -> Bool {
        !song.timedLyrics.isEmpty || !song.lyricsLines.isEmpty
    }

    static func lyricsNotice(for song: MankiSong) -> String {
        hasLyrics(for: song)
            ? "著作権保護のため、ここではダミーの短い歌詞行と訳だけを表示しています。"
            : placeholderMessage
    }
}
