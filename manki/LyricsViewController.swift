import UIKit

final class LyricsViewController: BaseViewController {
    private let song: MankiSong
    private let startLearning: Bool
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private let titleLabel = UILabel()
    private let artistLabel = UILabel()
    private let noteLabel = UILabel()
    private let keywordsLabel = UILabel()
    private let textView = UITextView()
    private var keywordsByWord: [String: MankiKeyword] = [:]

    init(song: MankiSong, startLearning: Bool = false) {
        self.song = song
        self.startLearning = startLearning
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Lyrics"
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
        keywordsLabel.applyMankiTextStyle(.caption, color: palette.text, numberOfLines: 0)
        textView.backgroundColor = palette.surface.withAlphaComponent(0.96)
        textView.textColor = palette.text
        textView.layer.cornerRadius = 22
        textView.layer.borderWidth = 2
        textView.layer.borderColor = palette.border.cgColor
        textView.linkTextAttributes = [
            .foregroundColor: palette.text,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .backgroundColor: palette.accent.withAlphaComponent(0.55)
        ]
    }

    private func configureUI() {
        keywordsByWord = Dictionary(uniqueKeysWithValues: song.keywords.map { ($0.word.lowercased(), $0) })

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = AppSpacing.s(14)

        [titleLabel, artistLabel, noteLabel, keywordsLabel, textView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.delegate = self
        textView.textContainerInset = UIEdgeInsets(top: AppSpacing.s(16), left: AppSpacing.s(12), bottom: AppSpacing.s(16), right: AppSpacing.s(12))

        view.addSubview(scrollView)
        scrollView.addSubview(stackView)

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

            textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 280)
        ])

        [titleLabel, artistLabel, noteLabel, keywordsLabel, textView].forEach {
            stackView.addArrangedSubview($0)
        }
    }

    private func applyContent() {
        titleLabel.text = song.title
        artistLabel.text = song.artist
        noteLabel.text = "著作権保護のため、ここでは短いサンプル文だけを表示しています。"
        keywordsLabel.text = "Keywords: " + song.keywords.map(\.word).joined(separator: " / ")
        textView.attributedText = makeLyricsAttributedText()
    }

    private func makeLyricsAttributedText() -> NSAttributedString {
        let palette = ThemeManager.palette()
        let attributed = NSMutableAttributedString()
        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: AppFont.jp(size: 16),
            .foregroundColor: palette.text
        ]

        for (lineIndex, line) in song.lyricsLines.enumerated() {
            let lineText = NSMutableAttributedString(string: line, attributes: baseAttributes)
            let lowercasedLine = line.lowercased()

            for keyword in song.keywords {
                let target = keyword.word.lowercased()
                var searchRange = lowercasedLine.startIndex..<lowercasedLine.endIndex
                while let range = lowercasedLine.range(of: target, options: [], range: searchRange) {
                    let nsRange = NSRange(range, in: line)
                    lineText.addAttributes([
                        .link: URL(string: "manki-keyword://\(keyword.word.lowercased())") as Any,
                        .backgroundColor: palette.accent.withAlphaComponent(0.36),
                        .underlineStyle: NSUnderlineStyle.single.rawValue
                    ], range: nsRange)
                    searchRange = range.upperBound..<lowercasedLine.endIndex
                }
            }

            attributed.append(lineText)
            if lineIndex < song.lyricsLines.count - 1 {
                attributed.append(NSAttributedString(string: "\n\n", attributes: baseAttributes))
            }
        }
        return attributed
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
