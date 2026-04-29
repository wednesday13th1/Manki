import Foundation

struct RecommendedSong {
    let mankiSong: MankiSong
    let appleMusicID: String
    let lyricsID: String
    let reason: String
}

final class RecommendedSongProvider {
    static let shared = RecommendedSongProvider()

    private init() {}

    func todayRecommendation() -> RecommendedSong? {
        let appleMusicID = "1122782283"
        let lyricsID = "1122782283"

        guard !appleMusicID.isEmpty, !lyricsID.isEmpty else {
            return nil
        }

        let song = MankiSong(
            id: appleMusicID,
            title: "Yellow",
            artist: "Coldplay",
            appleMusicID: appleMusicID,
            albumTitle: "Parachutes",
            artworkURL: nil,
            lyricsID: lyricsID,
            mood: "calm",
            level: "easy",
            keywords: [
                MankiKeyword(
                    word: "stars",
                    meaning: "星",
                    example: "The stars are bright tonight.",
                    difficulty: "easy"
                ),
                MankiKeyword(
                    word: "shine",
                    meaning: "輝く",
                    example: "The lights shine over the road.",
                    difficulty: "easy"
                ),
                MankiKeyword(
                    word: "yellow",
                    meaning: "黄色い",
                    example: "The field turned yellow in the sun.",
                    difficulty: "easy"
                )
            ],
            lyricsLines: [],
            previewURL: nil,
            timedLyrics: []
        )

        return RecommendedSong(
            mankiSong: song,
            appleMusicID: appleMusicID,
            lyricsID: lyricsID,
            reason: "今日の気分に合う1曲"
        )
    }
}
