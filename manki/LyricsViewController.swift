import UIKit
import MusicKit

final class LyricsViewController: BaseViewController {
    private let song: MankiSong
    private let appleMusicSong: Song?
    private let startLearning: Bool
    private let musicService = MusicService.shared
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private let titleLabel = UILabel()
    private let artistLabel = UILabel()
    private let noteLabel = UILabel()
    private let playbackCard = UIView()
    private let playPauseButton = UIButton(type: .system)
    private let timeLabel = UILabel()
    private let keywordsLabel = UILabel()
    private let textView = UITextView()
    private var keywordsByWord: [String: MankiKeyword] = [:]
    private var playbackTimer: Timer?
    private var currentLineIndex: Int = -1
    private var isPlaying = false

    init(song: MankiSong, appleMusicSong: Song? = nil, startLearning: Bool = false) {
        self.song = song
        self.appleMusicSong = appleMusicSong
        self.startLearning = startLearning
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        playbackTimer?.invalidate()
        Task { @MainActor [musicService] in
            musicService.stop()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Lyrics"
        configureBackButton()
        configureUI()
        applyContent()
        if startLearning, let firstKeyword = song.keywords.first {
            DispatchQueue.main.async { [weak self] in
                self?.presentKeywordModal(firstKeyword)
            }
        }
    }

    override func applyBaseTheme() {
        super.applyBaseTheme()
        let palette = ThemeManager.palette()
        titleLabel.applyMankiTextStyle(.screenTitle, color: palette.text, numberOfLines: 0)
        artistLabel.applyMankiTextStyle(.body, color: palette.mutedText, numberOfLines: 0)
        noteLabel.applyMankiTextStyle(.caption, color: palette.mutedText, numberOfLines: 0)
        timeLabel.applyMankiTextStyle(.sectionTitle, color: palette.text, alignment: .center, numberOfLines: 1)
        keywordsLabel.applyMankiTextStyle(.caption, color: palette.text, numberOfLines: 0)
        ThemeManager.styleCard(playbackCard, fillColor: palette.surface.withAlphaComponent(0.95))
        ThemeManager.stylePrimaryButton(playPauseButton)
        textView.backgroundColor = palette.surface.withAlphaComponent(0.96)
        textView.textColor = palette.text
        textView.layer.cornerRadius = 22
        textView.layer.borderWidth = 2
        textView.layer.borderColor = palette.border.cgColor
        textView.linkTextAttributes = [
            .foregroundColor: UIColor.white,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .backgroundColor: palette.accentStrong
        ]
        textView.attributedText = makeLyricsAttributedText(currentTime: musicService.currentPlaybackTime())
    }

    private func configureBackButton() {
        let backItem = UIBarButtonItem(title: "← Back", style: .plain, target: self, action: #selector(goBack))
        navigationItem.leftBarButtonItem = backItem
    }

    private func configureUI() {
        keywordsByWord = Dictionary(uniqueKeysWithValues: song.keywords.map { ($0.word.lowercased(), $0) })

        [scrollView, stackView, titleLabel, artistLabel, noteLabel, playbackCard, playPauseButton, timeLabel, keywordsLabel, textView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        stackView.axis = .vertical
        stackView.spacing = AppSpacing.s(14)

        playPauseButton.setTitle("再生", for: .normal)
        playPauseButton.addTarget(self, action: #selector(togglePlayback), for: .touchUpInside)

        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.delegate = self
        textView.textContainerInset = UIEdgeInsets(top: AppSpacing.s(16), left: AppSpacing.s(12), bottom: AppSpacing.s(16), right: AppSpacing.s(12))

        view.addSubview(scrollView)
        scrollView.addSubview(stackView)
        playbackCard.addSubview(playPauseButton)
        playbackCard.addSubview(timeLabel)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: AppSpacing.s(16)),
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: AppSpacing.s(16)),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -AppSpacing.s(16)),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -AppSpacing.s(24)),
            stackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -AppSpacing.s(32)),

            playPauseButton.topAnchor.constraint(equalTo: playbackCard.topAnchor, constant: AppSpacing.s(14)),
            playPauseButton.leadingAnchor.constraint(equalTo: playbackCard.leadingAnchor, constant: AppSpacing.s(14)),
            playPauseButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 96),

            timeLabel.centerYAnchor.constraint(equalTo: playPauseButton.centerYAnchor),
            timeLabel.leadingAnchor.constraint(equalTo: playPauseButton.trailingAnchor, constant: AppSpacing.s(12)),
            timeLabel.trailingAnchor.constraint(equalTo: playbackCard.trailingAnchor, constant: -AppSpacing.s(14)),
            timeLabel.bottomAnchor.constraint(equalTo: playbackCard.bottomAnchor, constant: -AppSpacing.s(14)),

            textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 340)
        ])

        [titleLabel, artistLabel, noteLabel, playbackCard, keywordsLabel, textView].forEach {
            stackView.addArrangedSubview($0)
        }
    }

    private func applyContent() {
        titleLabel.text = song.title
        artistLabel.text = song.artist
        noteLabel.text = LyricsRepository.shared.lyricsNotice(for: song)
        keywordsLabel.text = "Keywords: " + song.keywords.map(\.word).joined(separator: " / ")
        timeLabel.text = formattedTime(0)
        textView.attributedText = makeLyricsAttributedText(currentTime: 0)
    }

    private var timedLyrics: [TimedLyricLine] {
        let repositoryLyrics = LyricsRepository.shared.lyrics(for: song)
        if !repositoryLyrics.isEmpty {
            return repositoryLyrics
        }
        if !song.timedLyrics.isEmpty {
            return song.timedLyrics
        }
        if !song.lyricsLines.isEmpty {
            return song.lyricsLines.enumerated().map { index, text in
                TimedLyricLine(time: TimeInterval(index) * 3.5, text: text, japaneseTranslation: "ダミーの日本語訳です。")
            }
        }
        return []
    }

    private func makeLyricsAttributedText(currentTime: TimeInterval) -> NSAttributedString {
        let palette = ThemeManager.palette()
        if timedLyrics.isEmpty {
            return NSAttributedString(
                string: LyricsRepository.placeholderMessage,
                attributes: [
                    .font: AppFont.jp(size: 16, weight: .bold),
                    .foregroundColor: palette.mutedText
                ]
            )
        }
        let attributed = NSMutableAttributedString()
        let englishAttributes: [NSAttributedString.Key: Any] = [
            .font: AppFont.jp(size: 17, weight: .bold),
            .foregroundColor: palette.text
        ]
        let japaneseAttributes: [NSAttributedString.Key: Any] = [
            .font: AppFont.jp(size: 13),
            .foregroundColor: palette.mutedText
        ]
        let activeIndex = activeLineIndex(for: currentTime)

        for (lineIndex, line) in timedLyrics.enumerated() {
            let englishText = NSMutableAttributedString(string: line.text, attributes: englishAttributes)
            let lowercasedLine = line.text.lowercased()

            if lineIndex == activeIndex {
                englishText.addAttributes([
                    .backgroundColor: palette.accent.withAlphaComponent(0.22)
                ], range: NSRange(location: 0, length: (line.text as NSString).length))
            }

            for keyword in song.keywords {
                let target = keyword.word.lowercased()
                var searchRange = lowercasedLine.startIndex..<lowercasedLine.endIndex
                while let range = lowercasedLine.range(of: target, options: [], range: searchRange) {
                    let nsRange = NSRange(range, in: line.text)
                    englishText.addAttributes([
                        .link: URL(string: "manki-keyword://\(keyword.word.lowercased())") as Any,
                        .backgroundColor: palette.accentStrong,
                        .foregroundColor: UIColor.white,
                        .underlineStyle: NSUnderlineStyle.single.rawValue
                    ], range: nsRange)
                    searchRange = range.upperBound..<lowercasedLine.endIndex
                }
            }

            attributed.append(englishText)
            attributed.append(NSAttributedString(string: "\n", attributes: englishAttributes))

            let japaneseText = NSMutableAttributedString(string: line.japaneseTranslation, attributes: japaneseAttributes)
            if lineIndex == activeIndex {
                japaneseText.addAttributes([
                    .backgroundColor: palette.accent.withAlphaComponent(0.12)
                ], range: NSRange(location: 0, length: (line.japaneseTranslation as NSString).length))
            }
            attributed.append(japaneseText)

            if lineIndex < timedLyrics.count - 1 {
                attributed.append(NSAttributedString(string: "\n\n", attributes: japaneseAttributes))
            }
        }
        return attributed
    }

    @objc private func togglePlayback() {
        isPlaying ? pausePlayback() : startPlayback()
    }

    private func startPlayback() {
        print("Play tapped for:", song.id, song.title, song.artist, song.previewURL?.absoluteString ?? "no previewURL")
        print("Recommended playback check")
        print("Manki song id:", song.id)
        print("Apple Music ID:", song.appleMusicID ?? "nil")
        print("Lyrics ID:", song.lyricsID)
        print("Apple Song ID:", appleMusicSong?.id.rawValue ?? "nil")
        print("Title:", song.title)

        if let appleSong = appleMusicSong,
           let appleID = song.appleMusicID,
           appleSong.id.rawValue != appleID {
            showError("曲と歌詞のIDが一致しません")
            return
        }

        isPlaying = true
        playPauseButton.setTitle("一時停止", for: .normal)
        playbackTimer?.invalidate()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updatePlaybackUI()
        }
        updatePlaybackUI()

        Task { [weak self] in
            guard let self else { return }
            if #available(iOS 15.0, *), let appleSong = self.appleMusicSong {
                guard let appleID = self.song.appleMusicID, appleSong.id.rawValue == appleID else {
                    await MainActor.run {
                        self.pausePlayback()
                        self.showError("曲と歌詞のIDが一致しません")
                    }
                    return
                }
                let success = await MusicService.shared.playAppleMusicSong(appleSong, expectedSongID: self.song.id)
                if !success {
                    await MainActor.run {
                        self.pausePlayback()
                        self.showError("この曲を再生できませんでした。Apple Musicの登録状況を確認してください。")
                    }
                }
            } else if #available(iOS 15.0, *), let id = self.song.appleMusicID {
                guard !id.isEmpty else {
                    await MainActor.run {
                        self.pausePlayback()
                        self.showError("音源なし")
                    }
                    return
                }
                let success = await MusicService.shared.playAppleMusicSongByID(id, expectedSongID: self.song.id)
                if !success {
                    await MainActor.run {
                        self.pausePlayback()
                        self.showError("この曲を再生できませんでした。Apple Musicの登録状況を確認してください。")
                    }
                }
            } else if let previewURL = self.song.previewURL {
                MusicService.shared.playPreview(url: previewURL, songID: self.song.id)
            } else {
                await MainActor.run {
                    self.pausePlayback()
                    self.showError("音源なし")
                }
            }
        }
    }

    private func pausePlayback() {
        isPlaying = false
        playPauseButton.setTitle("再生", for: .normal)
        musicService.pauseSong()
        playbackTimer?.invalidate()
        playbackTimer = nil
        updatePlaybackUI()
    }

    private func updatePlaybackUI() {
        let currentTime = musicService.currentPlaybackTime()
        timeLabel.text = formattedTime(currentTime)
        textView.attributedText = makeLyricsAttributedText(currentTime: currentTime)

        let activeIndex = activeLineIndex(for: currentTime)
        if activeIndex != currentLineIndex {
            currentLineIndex = activeIndex
            scrollToLine(at: activeIndex)
        }

        if let last = timedLyrics.last, currentTime > last.time + 3.5 {
            pausePlayback()
            musicService.seek(to: 0)
            currentLineIndex = -1
            timeLabel.text = formattedTime(0)
            textView.attributedText = makeLyricsAttributedText(currentTime: 0)
        }
    }

    private func activeLineIndex(for time: TimeInterval) -> Int {
        var activeIndex = 0
        for (index, line) in timedLyrics.enumerated() where line.time <= time {
            activeIndex = index
        }
        return activeIndex
    }

    private func scrollToLine(at index: Int) {
        guard index >= 0, index < timedLyrics.count else { return }
        let prefixText = timedLyrics.prefix(index).map { "\($0.text)\n\($0.japaneseTranslation)" }.joined(separator: "\n\n")
        let location = prefixText.isEmpty ? 0 : (prefixText as NSString).length + 2
        let blockLength = ("\((timedLyrics[index].text))\n\((timedLyrics[index].japaneseTranslation))" as NSString).length
        textView.scrollRangeToVisible(NSRange(location: location, length: blockLength))
    }

    private func formattedTime(_ time: TimeInterval) -> String {
        let total = Int(time.rounded(.down))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    @objc private func goBack() {
        if let nav = navigationController {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    private func presentKeywordModal(_ keyword: MankiKeyword) {
        let message = [
            "meaning: \(keyword.meaning)",
            "example: \(keyword.example)",
            "difficulty: \(keyword.difficulty)"
        ].joined(separator: "\n")

        presentUnifiedModal(
            title: keyword.word,
            message: message,
            actions: [
                UnifiedModalAction(title: "単語カードに追加") {
                    addKeywordToWordCard(keyword)
                },
                UnifiedModalAction(title: "苦手単語に追加") {
                    addKeywordToWeakWords(keyword)
                },
                UnifiedModalAction(title: "閉じる", style: .cancel)
            ]
        )
    }

    private func showError(_ message: String) {
        presentUnifiedModal(
            title: "再生エラー",
            message: message,
            actions: [UnifiedModalAction(title: "OK")]
        )
    }
}

extension LyricsViewController: UITextViewDelegate {
    func textView(_ textView: UITextView,
                  shouldInteractWith URL: URL,
                  in characterRange: NSRange) -> Bool {
        guard URL.scheme == "manki-keyword",
              let host = URL.host,
              let keyword = keywordsByWord[host.lowercased()] else {
            return false
        }
        presentKeywordModal(keyword)
        return false
    }
}
