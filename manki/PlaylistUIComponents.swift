import UIKit

private enum PlaylistArtworkLoader {
    static let cache = NSCache<NSString, UIImage>()

    static func load(from url: URL, into imageView: UIImageView) -> URLSessionDataTask? {
        let cacheKey = url.absoluteString as NSString
        if let image = cache.object(forKey: cacheKey) {
            imageView.image = image
            return nil
        }

        let task = URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data, let image = UIImage(data: data) else { return }
            cache.setObject(image, forKey: cacheKey)
            DispatchQueue.main.async {
                imageView.image = image
            }
        }
        task.resume()
        return task
    }
}

final class EmotionBadgeLabel: UILabel {
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        layer.cornerRadius = 12
        layer.borderWidth = 1.5
        layer.masksToBounds = true
        textAlignment = .center
        numberOfLines = 1
        font = AppFont.jp(size: 11, weight: .bold)
    }

    func apply(tag: EmotionTag, palette: ThemePalette) {
        text = " \(tag.rawValue.uppercased()) "
        textColor = palette.text
        backgroundColor = tag.accentColor.withAlphaComponent(0.28)
        layer.borderColor = palette.border.cgColor
    }
}

final class DifficultyBadgeLabel: UILabel {
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        layer.cornerRadius = 12
        layer.borderWidth = 1.5
        layer.masksToBounds = true
        textAlignment = .center
        numberOfLines = 1
        font = AppFont.jp(size: 11, weight: .bold)
    }

    func apply(difficulty: PlaylistCardDifficulty, palette: ThemePalette) {
        text = " \(difficulty.rawValue.uppercased()) "
        textColor = palette.text
        switch difficulty {
        case .easy:
            backgroundColor = palette.background.withAlphaComponent(0.96)
        case .medium:
            backgroundColor = palette.surfaceAlt.withAlphaComponent(0.9)
        case .hard:
            backgroundColor = palette.accent.withAlphaComponent(0.3)
        }
        layer.borderColor = palette.border.cgColor
    }
}

final class RetroSummaryCell: UITableViewCell {
    static let reuseIdentifier = "RetroSummaryCell"

    private let cardView = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let metaLabel = UILabel()
    private let badgeLabel = EmotionBadgeLabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configureUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureUI()
    }

    private func configureUI() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        cardView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        metaLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false

        subtitleLabel.numberOfLines = 2
        metaLabel.numberOfLines = 1

        contentView.addSubview(cardView)
        cardView.addSubview(titleLabel)
        cardView.addSubview(subtitleLabel)
        cardView.addSubview(metaLabel)
        cardView.addSubview(badgeLabel)

        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AppSpacing.s(12)),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -AppSpacing.s(12)),
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: AppSpacing.s(8)),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -AppSpacing.s(8)),

            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: AppSpacing.s(14)),
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: AppSpacing.s(16)),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: badgeLabel.leadingAnchor, constant: -AppSpacing.s(8)),

            badgeLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            badgeLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -AppSpacing.s(16)),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: AppSpacing.s(8)),
            subtitleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: AppSpacing.s(16)),
            subtitleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -AppSpacing.s(16)),

            metaLabel.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: AppSpacing.s(10)),
            metaLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: AppSpacing.s(16)),
            metaLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -AppSpacing.s(16)),
            metaLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -AppSpacing.s(14))
        ])
    }

    func configure(title: String,
                   subtitle: String,
                   meta: String,
                   emotionTag: EmotionTag) {
        let palette = ThemeManager.palette()
        ThemeManager.styleCard(cardView, fillColor: palette.surface.withAlphaComponent(0.95))
        titleLabel.applyMankiTextStyle(.sectionTitle, color: palette.text, numberOfLines: 2)
        subtitleLabel.applyMankiTextStyle(.body, color: palette.mutedText, numberOfLines: 2)
        metaLabel.applyMankiTextStyle(.caption, color: palette.mutedText, numberOfLines: 1)
        titleLabel.text = title
        subtitleLabel.text = subtitle
        metaLabel.text = meta
        badgeLabel.apply(tag: emotionTag, palette: palette)
    }
}

final class AppleMusicSearchResultCell: UITableViewCell {
    static let reuseIdentifier = "AppleMusicSearchResultCell"

    private let cardView = UIView()
    private let artworkView = UIImageView()
    private let titleLabel = UILabel()
    private let artistLabel = UILabel()
    private let albumLabel = UILabel()
    private let metaLabel = UILabel()
    private let addButton = UIButton(type: .system)
    private var artworkTask: URLSessionDataTask?
    private var currentArtworkURL: URL?

    var onAddTapped: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configureUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureUI()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        artworkTask?.cancel()
        artworkTask = nil
        currentArtworkURL = nil
        artworkView.image = nil
        onAddTapped = nil
    }

    private func configureUI() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        [cardView, artworkView, titleLabel, artistLabel, albumLabel, metaLabel, addButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        artworkView.contentMode = .scaleAspectFill
        artworkView.clipsToBounds = true
        artworkView.layer.cornerRadius = 14
        artworkView.layer.borderWidth = 1.5

        [titleLabel, artistLabel, albumLabel, metaLabel].forEach {
            $0.numberOfLines = 0
        }

        addButton.setTitle("追加", for: .normal)
        addButton.addTarget(self, action: #selector(addTapped), for: .touchUpInside)

        contentView.addSubview(cardView)
        [artworkView, titleLabel, artistLabel, albumLabel, metaLabel, addButton].forEach {
            cardView.addSubview($0)
        }

        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AppSpacing.s(12)),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -AppSpacing.s(12)),
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: AppSpacing.s(8)),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -AppSpacing.s(8)),

            artworkView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: AppSpacing.s(14)),
            artworkView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: AppSpacing.s(14)),
            artworkView.widthAnchor.constraint(equalToConstant: 68),
            artworkView.heightAnchor.constraint(equalToConstant: 68),

            addButton.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -AppSpacing.s(14)),
            addButton.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            addButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 88),

            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: AppSpacing.s(14)),
            titleLabel.leadingAnchor.constraint(equalTo: artworkView.trailingAnchor, constant: AppSpacing.s(12)),
            titleLabel.trailingAnchor.constraint(equalTo: addButton.leadingAnchor, constant: -AppSpacing.s(10)),

            artistLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: AppSpacing.s(6)),
            artistLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            artistLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            albumLabel.topAnchor.constraint(equalTo: artistLabel.bottomAnchor, constant: AppSpacing.s(4)),
            albumLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            albumLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            metaLabel.topAnchor.constraint(equalTo: albumLabel.bottomAnchor, constant: AppSpacing.s(6)),
            metaLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            metaLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            metaLabel.bottomAnchor.constraint(lessThanOrEqualTo: cardView.bottomAnchor, constant: -AppSpacing.s(14)),

            cardView.bottomAnchor.constraint(greaterThanOrEqualTo: artworkView.bottomAnchor, constant: AppSpacing.s(14))
        ])
    }

    func configure(result: AppleMusicSongResult, alreadyAdded: Bool) {
        let palette = ThemeManager.palette()
        ThemeManager.styleCard(cardView, fillColor: palette.surface.withAlphaComponent(0.95))
        artworkView.layer.borderColor = palette.border.cgColor
        artworkView.backgroundColor = palette.surfaceAlt.withAlphaComponent(0.9)
        titleLabel.applyMankiTextStyle(.sectionTitle, color: palette.text, numberOfLines: 2)
        artistLabel.applyMankiTextStyle(.body, color: palette.mutedText, numberOfLines: 1)
        albumLabel.applyMankiTextStyle(.caption, color: palette.mutedText, numberOfLines: 2)
        metaLabel.applyMankiTextStyle(.caption, color: palette.mutedText, numberOfLines: 1)
        ThemeManager.stylePrimaryButton(addButton)
        addButton.isEnabled = !alreadyAdded
        addButton.alpha = alreadyAdded ? 0.7 : 1.0
        addButton.setTitle(alreadyAdded ? "追加済み" : "追加", for: .normal)

        titleLabel.text = result.title
        artistLabel.text = result.artistName
        albumLabel.text = result.albumTitle ?? "アルバム情報なし"
        metaLabel.text = [
            result.formattedDuration,
            result.previewURL == nil ? nil : "preview OK",
            "APPLE MUSIC"
        ].compactMap { $0 }.joined(separator: " / ")

        artworkTask?.cancel()
        artworkTask = nil
        currentArtworkURL = result.artworkURL
        artworkView.image = nil

        if let artworkURL = result.artworkURL {
            artworkTask = PlaylistArtworkLoader.load(from: artworkURL, into: artworkView)
        }
    }

    @objc private func addTapped() {
        onAddTapped?()
    }
}

final class PlaylistCardCell: UITableViewCell {
    static let reuseIdentifier = "PlaylistCardCell"

    private let noteView = NotebookBackgroundView()
    private let wordLabel = UILabel()
    private let meaningLabel = UILabel()
    private let exampleLabel = UILabel()
    private let songLabel = UILabel()
    private let memoLabel = UILabel()
    private let emotionBadge = EmotionBadgeLabel()
    private let difficultyBadge = DifficultyBadgeLabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configureUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureUI()
    }

    private func configureUI() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        [noteView, wordLabel, meaningLabel, exampleLabel, songLabel, memoLabel, emotionBadge, difficultyBadge].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        [wordLabel, meaningLabel, exampleLabel, songLabel, memoLabel].forEach {
            $0.numberOfLines = 0
        }

        contentView.addSubview(noteView)
        noteView.addSubview(wordLabel)
        noteView.addSubview(meaningLabel)
        noteView.addSubview(exampleLabel)
        noteView.addSubview(songLabel)
        noteView.addSubview(memoLabel)
        noteView.addSubview(emotionBadge)
        noteView.addSubview(difficultyBadge)

        NSLayoutConstraint.activate([
            noteView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AppSpacing.s(8)),
            noteView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -AppSpacing.s(8)),
            noteView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: AppSpacing.s(6)),
            noteView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -AppSpacing.s(6)),

            wordLabel.topAnchor.constraint(equalTo: noteView.topAnchor, constant: AppSpacing.s(12)),
            wordLabel.leadingAnchor.constraint(equalTo: noteView.leadingAnchor, constant: AppSpacing.s(36)),
            wordLabel.trailingAnchor.constraint(lessThanOrEqualTo: emotionBadge.leadingAnchor, constant: -AppSpacing.s(8)),

            emotionBadge.topAnchor.constraint(equalTo: noteView.topAnchor, constant: AppSpacing.s(12)),
            emotionBadge.trailingAnchor.constraint(equalTo: noteView.trailingAnchor, constant: -AppSpacing.s(12)),

            difficultyBadge.topAnchor.constraint(equalTo: emotionBadge.bottomAnchor, constant: AppSpacing.s(6)),
            difficultyBadge.trailingAnchor.constraint(equalTo: noteView.trailingAnchor, constant: -AppSpacing.s(12)),

            meaningLabel.topAnchor.constraint(equalTo: wordLabel.bottomAnchor, constant: AppSpacing.s(6)),
            meaningLabel.leadingAnchor.constraint(equalTo: noteView.leadingAnchor, constant: AppSpacing.s(36)),
            meaningLabel.trailingAnchor.constraint(equalTo: noteView.trailingAnchor, constant: -AppSpacing.s(12)),

            exampleLabel.topAnchor.constraint(equalTo: meaningLabel.bottomAnchor, constant: AppSpacing.s(6)),
            exampleLabel.leadingAnchor.constraint(equalTo: noteView.leadingAnchor, constant: AppSpacing.s(36)),
            exampleLabel.trailingAnchor.constraint(equalTo: noteView.trailingAnchor, constant: -AppSpacing.s(12)),

            songLabel.topAnchor.constraint(equalTo: exampleLabel.bottomAnchor, constant: AppSpacing.s(6)),
            songLabel.leadingAnchor.constraint(equalTo: noteView.leadingAnchor, constant: AppSpacing.s(36)),
            songLabel.trailingAnchor.constraint(equalTo: noteView.trailingAnchor, constant: -AppSpacing.s(12)),

            memoLabel.topAnchor.constraint(equalTo: songLabel.bottomAnchor, constant: AppSpacing.s(6)),
            memoLabel.leadingAnchor.constraint(equalTo: noteView.leadingAnchor, constant: AppSpacing.s(36)),
            memoLabel.trailingAnchor.constraint(equalTo: noteView.trailingAnchor, constant: -AppSpacing.s(12)),
            memoLabel.bottomAnchor.constraint(equalTo: noteView.bottomAnchor, constant: -AppSpacing.s(12))
        ])
    }

    func configure(card: PlaylistCard) {
        let palette = ThemeManager.palette()
        wordLabel.font = AppFont.en(size: 18, weight: .bold)
        meaningLabel.font = AppFont.jp(size: 16, weight: .bold)
        exampleLabel.font = AppFont.jp(size: 13)
        songLabel.font = AppFont.jp(size: 12, weight: .bold)
        memoLabel.font = AppFont.jp(size: 12)

        wordLabel.textColor = palette.text
        meaningLabel.textColor = palette.text
        exampleLabel.textColor = palette.mutedText
        songLabel.textColor = palette.mutedText
        memoLabel.textColor = palette.mutedText

        wordLabel.text = card.word
        meaningLabel.text = card.meaning
        exampleLabel.text = card.examplePhrase.isEmpty ? "例文なし" : "例文: \(card.examplePhrase)"
        songLabel.text = "SONG: \(card.sourceSongTitle)"
        memoLabel.text = card.memo.isEmpty ? "メモなし" : "MEMO: \(card.memo)"

        emotionBadge.apply(tag: card.emotionTag, palette: palette)
        difficultyBadge.apply(difficulty: card.difficulty, palette: palette)
    }
}

final class FilterChipButton: UIButton {
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        titleLabel?.font = AppFont.jp(size: 13, weight: .bold)
        applyMankiButtonMetrics()
    }

    func apply(title: String, selected: Bool) {
        setTitle(title, for: .normal)
        ThemeManager.stylePixelOutlineButton(self, selected: selected)
    }
}
