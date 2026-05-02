import UIKit
import MusicKit
import AVFoundation

@MainActor
final class MusicKitPlayerViewController: BaseViewController {
    private let playbackController = MusicKitPlaybackController()

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    private let statusLabel = UILabel()
    private let authorizeButton = UIButton(type: .system)

    private let recommendationCard = UIView()
    private let recommendationStack = UIStackView()
    private let recommendationMediaStack = UIStackView()
    private let recommendationTextStack = UIStackView()
    private let recommendationArtworkView = UIImageView()
    private let recommendationTitleLabel = UILabel()
    private let recommendationArtistLabel = UILabel()
    private let recommendationPlayButton = UIButton(type: .system)
    private var recommendationArtworkWidthConstraint: NSLayoutConstraint?
    private var recommendationArtworkHeightConstraint: NSLayoutConstraint?

    private let playlistCard = UIView()
    private let playlistStack = UIStackView()
    private let playlistHeaderStack = UIStackView()
    private let playlistControlsStack = UIStackView()
    private let shuffleInfoStack = UIStackView()
    private let playlistTitleLabel = UILabel()
    private let playlistHeaderSpacer = UIView()
    private let playlistSelectButton = UIButton(type: .system)
    private let playlistNameLabel = UILabel()
    private let shuffleSwitch = UISwitch()
    private let shuffleLabel = UILabel()
    private let playlistControlsSpacer = UIView()
    private let playAllButton = UIButton(type: .system)
    private let tracksTableView = UITableView(frame: .zero, style: .plain)
    private var tracksTableHeightConstraint: NSLayoutConstraint?

    private let nowPlayingCard = UIView()
    private let nowPlayingStack = UIStackView()
    private let nowPlayingMediaStack = UIStackView()
    private let nowPlayingTextStack = UIStackView()
    private let nowPlayingArtworkView = UIImageView()
    private let nowPlayingTitleLabel = UILabel()
    private let nowPlayingArtistLabel = UILabel()
    private let playbackButtonsStack = UIStackView()
    private let previousButton = UIButton(type: .system)
    private let playPauseButton = UIButton(type: .system)
    private let nextButton = UIButton(type: .system)
    private var nowPlayingArtworkWidthConstraint: NSLayoutConstraint?
    private var nowPlayingArtworkHeightConstraint: NSLayoutConstraint?

    private let lyricsCard = UIView()
    private let lyricsStack = UIStackView()
    private let lyricsTitleLabel = UILabel()
    private let lyricsNoteLabel = UILabel()
    private let targetLevelLabel = UILabel()
    private let keywordTitleLabel = UILabel()
    private let keywordStatusLabel = UILabel()
    private let keywordScrollView = UIScrollView()
    private let keywordStackView = UIStackView()
    private let addKeywordsButton = UIButton(type: .system)
    private let lyricsTextView = UITextView()
    private var keywordScrollHeightConstraint: NSLayoutConstraint?
    private var lyricsHeightConstraint: NSLayoutConstraint?

    private var recommendationArtworkTask: Task<Void, Never>?
    private var nowPlayingArtworkTask: Task<Void, Never>?
    private var keywordExtractionTask: Task<Void, Never>?
    private var goalLevelObserver: NSObjectProtocol?
    private let keywordExtractor: KeywordExtracting = LocalKeywordExtractor()
    private var extractedKeywords: [ExtractedKeyword] = []
    private var selectedKeywordIDs = Set<UUID>()
    private var focusedKeyword: ExtractedKeyword?
    private var keywordButtons: [FilterChipButton] = []
    private var lastKeywordSignature = ""
    private var lastRenderedPlaylistTrackIDs: [MusicItemID] = []
    private var lastAppliedGoalText = ""
    private var recommendationArtworkURL: URL?
    private var nowPlayingArtworkURL: URL?
    private var lastRenderedStatusMessage = ""
    private var lastRenderedPlaylistTitle = ""
    private var lastRenderedLyricsNotice = ""
    private var keywordStatusMessage = ""
    private var needsDeferredRender = false

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Music"
        configureUI()
        bindState()
        observeGoalLevel()
        Task { await bootstrap() }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        recommendationArtworkTask?.cancel()
        nowPlayingArtworkTask?.cancel()
        keywordExtractionTask?.cancel()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if needsDeferredRender {
            needsDeferredRender = false
        }
        render()
    }

    deinit {
        if let goalLevelObserver {
            NotificationCenter.default.removeObserver(goalLevelObserver)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateResponsiveLayout()
    }

    override func applyBaseTheme() {
        super.applyBaseTheme()
        let palette = ThemeManager.palette()

        [statusLabel, recommendationTitleLabel, recommendationArtistLabel, playlistTitleLabel, playlistNameLabel, shuffleLabel, nowPlayingTitleLabel, nowPlayingArtistLabel, lyricsTitleLabel, lyricsNoteLabel, targetLevelLabel, keywordTitleLabel, keywordStatusLabel].forEach {
            $0.textColor = palette.text
        }
        recommendationArtistLabel.textColor = palette.mutedText
        playlistNameLabel.textColor = palette.mutedText
        nowPlayingArtistLabel.textColor = palette.mutedText
        lyricsNoteLabel.textColor = palette.mutedText
        targetLevelLabel.textColor = palette.accentStrong
        keywordStatusLabel.textColor = palette.mutedText
        statusLabel.textColor = palette.mutedText

        [recommendationCard, playlistCard, nowPlayingCard, lyricsCard].forEach {
            ThemeManager.styleCard($0, fillColor: palette.surface.withAlphaComponent(0.95))
        }

        ThemeManager.stylePrimaryButton(authorizeButton)
        ThemeManager.stylePrimaryButton(recommendationPlayButton)
        ThemeManager.stylePrimaryButton(playAllButton)
        ThemeManager.styleSecondaryButton(playlistSelectButton)
        ThemeManager.styleSecondaryButton(previousButton)
        ThemeManager.stylePrimaryButton(playPauseButton)
        ThemeManager.styleSecondaryButton(nextButton)
        ThemeManager.stylePrimaryButton(addKeywordsButton)

        lyricsTextView.backgroundColor = palette.surface.withAlphaComponent(0.92)
        lyricsTextView.textColor = palette.text
        lyricsTextView.layer.borderWidth = 2
        lyricsTextView.layer.borderColor = palette.border.cgColor
        lyricsTextView.layer.cornerRadius = 18
        lyricsTextView.tintColor = palette.accentStrong

        tracksTableView.backgroundColor = .clear
        tracksTableView.separatorStyle = .none
        view.setNeedsLayout()
    }

    private func configureUI() {
        [scrollView, contentStack, statusLabel, authorizeButton, recommendationCard, recommendationStack, recommendationMediaStack, recommendationTextStack, recommendationArtworkView, recommendationTitleLabel, recommendationArtistLabel, recommendationPlayButton, playlistCard, playlistStack, playlistHeaderStack, playlistControlsStack, shuffleInfoStack, playlistTitleLabel, playlistHeaderSpacer, playlistSelectButton, playlistNameLabel, shuffleLabel, playlistControlsSpacer, playAllButton, tracksTableView, nowPlayingCard, nowPlayingStack, nowPlayingMediaStack, nowPlayingTextStack, nowPlayingArtworkView, nowPlayingTitleLabel, nowPlayingArtistLabel, playbackButtonsStack, previousButton, playPauseButton, nextButton, lyricsCard, lyricsStack, lyricsTitleLabel, lyricsNoteLabel, targetLevelLabel, keywordTitleLabel, keywordStatusLabel, keywordScrollView, keywordStackView, addKeywordsButton, lyricsTextView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        contentStack.axis = .vertical
        contentStack.spacing = AppSpacing.s(16)

        statusLabel.applyMankiTextStyle(.caption, color: ThemeManager.palette().mutedText, numberOfLines: 0)
        authorizeButton.setTitle("Apple Musicを許可", for: .normal)
        authorizeButton.addTarget(self, action: #selector(authorizeTapped), for: .touchUpInside)
        authorizeButton.adjustsImageWhenHighlighted = false

        recommendationArtworkView.contentMode = .scaleAspectFill
        recommendationArtworkView.clipsToBounds = true
        recommendationArtworkView.layer.cornerRadius = 14
        recommendationArtworkView.layer.borderWidth = 1.5

        recommendationStack.axis = .vertical
        recommendationStack.spacing = AppSpacing.s(12)
        recommendationStack.isLayoutMarginsRelativeArrangement = true
        recommendationStack.layoutMargins = UIEdgeInsets(top: AppSpacing.s(16), left: AppSpacing.s(16), bottom: AppSpacing.s(16), right: AppSpacing.s(16))

        recommendationMediaStack.axis = .horizontal
        recommendationMediaStack.spacing = AppSpacing.s(14)
        recommendationMediaStack.alignment = .top

        recommendationTextStack.axis = .vertical
        recommendationTextStack.spacing = AppSpacing.s(8)
        recommendationTextStack.alignment = .fill

        recommendationTitleLabel.applyMankiTextStyle(.sectionTitle, color: ThemeManager.palette().text, numberOfLines: 2)
        recommendationArtistLabel.applyMankiTextStyle(.body, color: ThemeManager.palette().mutedText, numberOfLines: 2)
        recommendationPlayButton.setTitle("おすすめ再生", for: .normal)
        recommendationPlayButton.addTarget(self, action: #selector(playRecommendationTapped), for: .touchUpInside)
        recommendationPlayButton.adjustsImageWhenHighlighted = false

        playlistStack.axis = .vertical
        playlistStack.spacing = AppSpacing.s(12)
        playlistStack.isLayoutMarginsRelativeArrangement = true
        playlistStack.layoutMargins = UIEdgeInsets(top: AppSpacing.s(16), left: AppSpacing.s(16), bottom: AppSpacing.s(12), right: AppSpacing.s(16))

        playlistHeaderStack.axis = .horizontal
        playlistHeaderStack.spacing = AppSpacing.s(10)
        playlistHeaderStack.alignment = .center

        shuffleInfoStack.axis = .horizontal
        shuffleInfoStack.spacing = AppSpacing.s(8)
        shuffleInfoStack.alignment = .center

        playlistControlsStack.axis = .horizontal
        playlistControlsStack.spacing = AppSpacing.s(10)
        playlistControlsStack.alignment = .center

        playlistTitleLabel.applyMankiTextStyle(.sectionTitle, color: ThemeManager.palette().text, numberOfLines: 2)
        playlistTitleLabel.text = "プレイリスト"
        playlistSelectButton.setTitle("選択", for: .normal)
        playlistSelectButton.addTarget(self, action: #selector(selectPlaylistTapped), for: .touchUpInside)
        playlistSelectButton.adjustsImageWhenHighlighted = false
        playlistNameLabel.applyMankiTextStyle(.body, color: ThemeManager.palette().mutedText, numberOfLines: 0)
        shuffleLabel.applyMankiTextStyle(.caption, color: ThemeManager.palette().text, numberOfLines: 1)
        shuffleLabel.text = "シャッフル"
        shuffleSwitch.addTarget(self, action: #selector(shuffleChanged), for: .valueChanged)
        playAllButton.setTitle("全曲再生", for: .normal)
        playAllButton.addTarget(self, action: #selector(playAllTapped), for: .touchUpInside)
        playAllButton.adjustsImageWhenHighlighted = false

        tracksTableView.dataSource = self
        tracksTableView.delegate = self
        tracksTableView.rowHeight = UITableView.automaticDimension
        tracksTableView.estimatedRowHeight = 58
        tracksTableView.isScrollEnabled = false
        tracksTableView.register(MusicKitTrackCell.self, forCellReuseIdentifier: MusicKitTrackCell.reuseIdentifier)

        nowPlayingStack.axis = .vertical
        nowPlayingStack.spacing = AppSpacing.s(12)
        nowPlayingStack.isLayoutMarginsRelativeArrangement = true
        nowPlayingStack.layoutMargins = UIEdgeInsets(top: AppSpacing.s(16), left: AppSpacing.s(16), bottom: AppSpacing.s(16), right: AppSpacing.s(16))

        nowPlayingMediaStack.axis = .horizontal
        nowPlayingMediaStack.spacing = AppSpacing.s(14)
        nowPlayingMediaStack.alignment = .top

        nowPlayingTextStack.axis = .vertical
        nowPlayingTextStack.spacing = AppSpacing.s(6)

        nowPlayingArtworkView.contentMode = .scaleAspectFill
        nowPlayingArtworkView.clipsToBounds = true
        nowPlayingArtworkView.layer.cornerRadius = 14
        nowPlayingArtworkView.layer.borderWidth = 1.5
        nowPlayingTitleLabel.applyMankiTextStyle(.sectionTitle, color: ThemeManager.palette().text, numberOfLines: 2)
        nowPlayingArtistLabel.applyMankiTextStyle(.body, color: ThemeManager.palette().mutedText, numberOfLines: 2)

        playbackButtonsStack.axis = .horizontal
        playbackButtonsStack.spacing = AppSpacing.s(10)
        playbackButtonsStack.distribution = .fillEqually

        previousButton.setTitle("前へ", for: .normal)
        playPauseButton.setTitle("再生", for: .normal)
        nextButton.setTitle("次へ", for: .normal)

        previousButton.addTarget(self, action: #selector(previousTapped), for: .touchUpInside)
        playPauseButton.addTarget(self, action: #selector(playPauseTapped), for: .touchUpInside)
        nextButton.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
        previousButton.adjustsImageWhenHighlighted = false
        playPauseButton.adjustsImageWhenHighlighted = false
        nextButton.adjustsImageWhenHighlighted = false

        lyricsStack.axis = .vertical
        lyricsStack.spacing = AppSpacing.s(10)
        lyricsStack.isLayoutMarginsRelativeArrangement = true
        lyricsStack.layoutMargins = UIEdgeInsets(top: AppSpacing.s(16), left: AppSpacing.s(16), bottom: AppSpacing.s(16), right: AppSpacing.s(16))

        lyricsTitleLabel.applyMankiTextStyle(.sectionTitle, color: ThemeManager.palette().text, numberOfLines: 1)
        lyricsTitleLabel.text = "歌詞"
        lyricsNoteLabel.applyMankiTextStyle(.caption, color: ThemeManager.palette().mutedText, numberOfLines: 0)
        targetLevelLabel.applyMankiTextStyle(.caption, color: ThemeManager.palette().accentStrong, numberOfLines: 1)
        keywordTitleLabel.applyMankiTextStyle(.caption, color: ThemeManager.palette().text, numberOfLines: 1)
        keywordTitleLabel.text = "この曲からおすすめ単語"
        keywordStatusLabel.applyMankiTextStyle(.caption, color: ThemeManager.palette().mutedText, numberOfLines: 0)
        keywordScrollView.showsHorizontalScrollIndicator = false
        keywordScrollView.alwaysBounceHorizontal = true
        keywordStackView.axis = .horizontal
        keywordStackView.spacing = AppSpacing.s(8)
        keywordStackView.alignment = .fill
        addKeywordsButton.setTitle("選択した単語をセットに追加", for: .normal)
        addKeywordsButton.addTarget(self, action: #selector(addSelectedKeywordsTapped), for: .touchUpInside)
        lyricsTextView.isEditable = false
        lyricsTextView.isScrollEnabled = true
        lyricsTextView.textContainerInset = UIEdgeInsets(top: AppSpacing.s(16), left: AppSpacing.s(12), bottom: AppSpacing.s(16), right: AppSpacing.s(12))
        lyricsTextView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        [recommendationPlayButton, playlistSelectButton, playAllButton, previousButton, playPauseButton, nextButton, addKeywordsButton].forEach {
            $0.setContentCompressionResistancePriority(.required, for: .horizontal)
            $0.setContentHuggingPriority(.required, for: .horizontal)
            $0.titleLabel?.lineBreakMode = .byTruncatingTail
        }
        recommendationTitleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        recommendationArtistLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        nowPlayingTitleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        nowPlayingArtistLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        playlistHeaderSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        playlistControlsSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        recommendationCard.addSubview(recommendationStack)
        recommendationMediaStack.addArrangedSubview(recommendationArtworkView)
        recommendationTextStack.addArrangedSubview(recommendationTitleLabel)
        recommendationTextStack.addArrangedSubview(recommendationArtistLabel)
        recommendationMediaStack.addArrangedSubview(recommendationTextStack)
        recommendationStack.addArrangedSubview(recommendationMediaStack)
        recommendationStack.addArrangedSubview(recommendationPlayButton)

        playlistCard.addSubview(playlistStack)
        playlistHeaderStack.addArrangedSubview(playlistTitleLabel)
        playlistHeaderStack.addArrangedSubview(playlistHeaderSpacer)
        playlistHeaderStack.addArrangedSubview(playlistSelectButton)
        shuffleInfoStack.addArrangedSubview(shuffleLabel)
        shuffleInfoStack.addArrangedSubview(shuffleSwitch)
        playlistControlsStack.addArrangedSubview(shuffleInfoStack)
        playlistControlsStack.addArrangedSubview(playlistControlsSpacer)
        playlistControlsStack.addArrangedSubview(playAllButton)
        playlistStack.addArrangedSubview(playlistHeaderStack)
        playlistStack.addArrangedSubview(playlistNameLabel)
        playlistStack.addArrangedSubview(playlistControlsStack)
        playlistStack.addArrangedSubview(tracksTableView)

        nowPlayingCard.addSubview(nowPlayingStack)
        nowPlayingMediaStack.addArrangedSubview(nowPlayingArtworkView)
        nowPlayingTextStack.addArrangedSubview(nowPlayingTitleLabel)
        nowPlayingTextStack.addArrangedSubview(nowPlayingArtistLabel)
        nowPlayingMediaStack.addArrangedSubview(nowPlayingTextStack)
        nowPlayingStack.addArrangedSubview(nowPlayingMediaStack)
        playbackButtonsStack.addArrangedSubview(previousButton)
        playbackButtonsStack.addArrangedSubview(playPauseButton)
        playbackButtonsStack.addArrangedSubview(nextButton)
        nowPlayingStack.addArrangedSubview(playbackButtonsStack)

        lyricsCard.addSubview(lyricsStack)
        keywordScrollView.addSubview(keywordStackView)
        lyricsStack.addArrangedSubview(lyricsTitleLabel)
        lyricsStack.addArrangedSubview(targetLevelLabel)
        lyricsStack.addArrangedSubview(lyricsNoteLabel)
        lyricsStack.addArrangedSubview(keywordTitleLabel)
        lyricsStack.addArrangedSubview(keywordStatusLabel)
        lyricsStack.addArrangedSubview(keywordScrollView)
        lyricsStack.addArrangedSubview(addKeywordsButton)
        lyricsStack.addArrangedSubview(lyricsTextView)

        [statusLabel, authorizeButton, recommendationCard, playlistCard, nowPlayingCard, lyricsCard].forEach {
            contentStack.addArrangedSubview($0)
        }

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: AppSpacing.s(16)),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: AppSpacing.s(16)),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -AppSpacing.s(16)),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -AppSpacing.s(24)),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -AppSpacing.s(32)),

            recommendationStack.topAnchor.constraint(equalTo: recommendationCard.topAnchor),
            recommendationStack.leadingAnchor.constraint(equalTo: recommendationCard.leadingAnchor),
            recommendationStack.trailingAnchor.constraint(equalTo: recommendationCard.trailingAnchor),
            recommendationStack.bottomAnchor.constraint(equalTo: recommendationCard.bottomAnchor),

            recommendationPlayButton.widthAnchor.constraint(lessThanOrEqualTo: recommendationStack.widthAnchor),

            playlistStack.topAnchor.constraint(equalTo: playlistCard.topAnchor),
            playlistStack.leadingAnchor.constraint(equalTo: playlistCard.leadingAnchor),
            playlistStack.trailingAnchor.constraint(equalTo: playlistCard.trailingAnchor),
            playlistStack.bottomAnchor.constraint(equalTo: playlistCard.bottomAnchor),

            nowPlayingStack.topAnchor.constraint(equalTo: nowPlayingCard.topAnchor),
            nowPlayingStack.leadingAnchor.constraint(equalTo: nowPlayingCard.leadingAnchor),
            nowPlayingStack.trailingAnchor.constraint(equalTo: nowPlayingCard.trailingAnchor),
            nowPlayingStack.bottomAnchor.constraint(equalTo: nowPlayingCard.bottomAnchor),

            lyricsStack.topAnchor.constraint(equalTo: lyricsCard.topAnchor),
            lyricsStack.leadingAnchor.constraint(equalTo: lyricsCard.leadingAnchor),
            lyricsStack.trailingAnchor.constraint(equalTo: lyricsCard.trailingAnchor),
            lyricsStack.bottomAnchor.constraint(equalTo: lyricsCard.bottomAnchor),

            keywordStackView.topAnchor.constraint(equalTo: keywordScrollView.contentLayoutGuide.topAnchor),
            keywordStackView.leadingAnchor.constraint(equalTo: keywordScrollView.contentLayoutGuide.leadingAnchor),
            keywordStackView.trailingAnchor.constraint(equalTo: keywordScrollView.contentLayoutGuide.trailingAnchor),
            keywordStackView.bottomAnchor.constraint(equalTo: keywordScrollView.contentLayoutGuide.bottomAnchor),
            keywordStackView.heightAnchor.constraint(equalTo: keywordScrollView.frameLayoutGuide.heightAnchor)
        ])

        recommendationArtworkWidthConstraint = recommendationArtworkView.widthAnchor.constraint(equalToConstant: 96)
        recommendationArtworkHeightConstraint = recommendationArtworkView.heightAnchor.constraint(equalTo: recommendationArtworkView.widthAnchor)
        nowPlayingArtworkWidthConstraint = nowPlayingArtworkView.widthAnchor.constraint(equalToConstant: 72)
        nowPlayingArtworkHeightConstraint = nowPlayingArtworkView.heightAnchor.constraint(equalTo: nowPlayingArtworkView.widthAnchor)
        keywordScrollHeightConstraint = keywordScrollView.heightAnchor.constraint(equalToConstant: 38)
        lyricsHeightConstraint = lyricsTextView.heightAnchor.constraint(equalToConstant: 280)

        NSLayoutConstraint.activate([
            recommendationArtworkWidthConstraint,
            recommendationArtworkHeightConstraint,
            nowPlayingArtworkWidthConstraint,
            nowPlayingArtworkHeightConstraint,
            keywordScrollHeightConstraint,
            lyricsHeightConstraint
        ].compactMap { $0 })

        tracksTableHeightConstraint = tracksTableView.heightAnchor.constraint(equalToConstant: 88)
        tracksTableHeightConstraint?.isActive = true
        updateResponsiveLayout()
    }

    private func bindState() {
        playbackController.onStateChange = { [weak self] in
            self?.render()
        }
    }

    private func observeGoalLevel() {
        goalLevelObserver = NotificationCenter.default.addObserver(
            forName: .englishGoalLevelDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.lastKeywordSignature = ""
                self?.render()
            }
        }
    }

    private func bootstrap() async {
        await playbackController.requestAuthorizationIfNeeded()
        await playbackController.loadInitialData()
    }

    private func render() {
        guard isViewLoaded else { return }
        let isInWindow = view.window != nil
        if !isInWindow {
            needsDeferredRender = true
        }

        authorizeButton.isHidden = playbackController.isAuthorized
        let goalText = EnglishGoalLevelStore.storedText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if lastRenderedStatusMessage != playbackController.statusMessage {
            statusLabel.text = playbackController.statusMessage
            lastRenderedStatusMessage = playbackController.statusMessage
        }
        if lastAppliedGoalText != goalText {
            targetLevelLabel.text = goalText.isEmpty ? "目標：未設定" : "目標：\(goalText)"
            lastAppliedGoalText = goalText
        }

        recommendationTitleLabel.text = playbackController.recommendedSong?.title ?? "今日のおすすめはまだありません"
        recommendationArtistLabel.text = playbackController.recommendedSong?.artistName ?? "Apple Musicに接続するとおすすめを取得できます。"
        recommendationPlayButton.isEnabled = playbackController.recommendedSong != nil && playbackController.canPlayCatalogContent
        updateArtwork(playbackController.recommendedSong?.artwork?.url(width: 320, height: 320), into: recommendationArtworkView, task: &recommendationArtworkTask, previousURL: &recommendationArtworkURL)

        let playlistTitle = playbackController.selectedPlaylist?.title ?? "プレイリスト未選択"
        if lastRenderedPlaylistTitle != playlistTitle {
            playlistNameLabel.text = playlistTitle
            lastRenderedPlaylistTitle = playlistTitle
        }
        playAllButton.isEnabled = playbackController.selectedPlaylist != nil && !playbackController.playlistTracks.isEmpty && playbackController.canPlayCatalogContent
        shuffleSwitch.isOn = playbackController.shuffleEnabled
        updateTracksTableHeight()
        let trackIDs = playbackController.playlistTracks.map(\.id)
        if lastRenderedPlaylistTrackIDs != trackIDs {
            lastRenderedPlaylistTrackIDs = trackIDs
            if isInWindow {
                tracksTableView.reloadData()
            }
        } else if isInWindow {
            tracksTableView.setNeedsLayout()
        }

        nowPlayingTitleLabel.text = playbackController.currentSong?.title ?? "再生中の曲はありません"
        nowPlayingArtistLabel.text = playbackController.currentSong?.artistName ?? "曲やプレイリストを再生してください"
        playPauseButton.setTitle(playbackController.isPlaying ? "停止" : "再生", for: .normal)
        previousButton.isEnabled = playbackController.canControlPlayback
        playPauseButton.isEnabled = playbackController.canControlPlayback
        nextButton.isEnabled = playbackController.canControlPlayback
        updateArtwork(playbackController.currentSong?.artwork?.url(width: 320, height: 320), into: nowPlayingArtworkView, task: &nowPlayingArtworkTask, previousURL: &nowPlayingArtworkURL)

        refreshExtractedKeywordsIfNeeded()
        renderKeywords()
        updateAddKeywordsButton()
        renderLyrics()
        if isInWindow {
            updateResponsiveLayout()
        }
    }

    private func renderLyrics() {
        if lastRenderedLyricsNotice != playbackController.lyricsNotice {
            lyricsNoteLabel.text = playbackController.lyricsNotice
            lastRenderedLyricsNotice = playbackController.lyricsNotice
        }
        let palette = ThemeManager.palette()
        let attributed = NSMutableAttributedString()

        if playbackController.currentLyrics.isEmpty {
            attributed.append(
                NSAttributedString(
                    string: playbackController.lyricsNotice,
                    attributes: [
                        .font: AppFont.jp(size: 16, weight: .bold),
                        .foregroundColor: palette.mutedText
                    ]
                )
            )
            lyricsTextView.attributedText = attributed
            return
        }

        let activeIndex = playbackController.activeLyricLineIndex
        for (index, line) in playbackController.currentLyrics.enumerated() {
            let lineRange = NSRange(location: attributed.length, length: (line.text as NSString).length)
            let isSelectedLine = focusedKeyword?.sourceLine == line.text
            let attrs: [NSAttributedString.Key: Any] = [
                .font: AppFont.jp(size: index == activeIndex ? 18 : 16, weight: index == activeIndex ? .bold : .regular),
                .foregroundColor: index == activeIndex ? palette.text : palette.mutedText,
                .backgroundColor: isSelectedLine
                    ? palette.accentStrong.withAlphaComponent(0.28)
                    : (index == activeIndex ? palette.accent.withAlphaComponent(0.24) : UIColor.clear)
            ]
            attributed.append(NSAttributedString(string: line.text, attributes: attrs))
            highlightKeywords(in: attributed, line: line.text, lineRange: lineRange, activeIndex: index == activeIndex, selectedLine: isSelectedLine)
            if index < playbackController.currentLyrics.count - 1 {
                attributed.append(NSAttributedString(string: "\n\n", attributes: attrs))
            }
        }

        lyricsTextView.attributedText = attributed
        if view.window != nil {
            scrollLyricsToActiveLine()
        }
    }

    private func scrollLyricsToActiveLine() {
        guard view.window != nil else { return }
        let index = playbackController.activeLyricLineIndex
        guard index >= 0, index < playbackController.currentLyrics.count else { return }
        let prefix = playbackController.currentLyrics.prefix(index).map(\.text).joined(separator: "\n\n")
        let location = prefix.isEmpty ? 0 : (prefix as NSString).length + 2
        let lineLength = (playbackController.currentLyrics[index].text as NSString).length
        lyricsTextView.scrollRangeToVisible(NSRange(location: location, length: lineLength))
    }

    private func updateTracksTableHeight() {
        let rowCount = max(playbackController.playlistTracks.count, 1)
        let compactRows = isCompactWidth ? 4 : 5
        tracksTableHeightConstraint?.constant = CGFloat(min(rowCount, compactRows)) * 64
    }

    private func refreshExtractedKeywordsIfNeeded() {
        let currentSongID = playbackController.currentSong?.id.rawValue ?? "none"
        let goalText = EnglishGoalLevelStore.storedText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let lyrics = playbackController.currentLyrics.map(\.text).joined(separator: "\n")

        if goalText.isEmpty {
            keywordExtractionTask?.cancel()
            extractedKeywords = []
            selectedKeywordIDs.removeAll()
            focusedKeyword = nil
            updateKeywordStatus("設定で目標を入力すると、この曲に合った単語をおすすめできます")
            lastKeywordSignature = "missing-goal-\(currentSongID)"
            return
        }

        guard !lyrics.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            keywordExtractionTask?.cancel()
            extractedKeywords = []
            selectedKeywordIDs.removeAll()
            focusedKeyword = nil
            updateKeywordStatus("この曲の歌詞がまだありません")
            lastKeywordSignature = "missing-lyrics-\(currentSongID)"
            return
        }

        let songTitle = playbackController.currentSong?.title ?? "この曲"
        let artistName = playbackController.currentSong?.artistName ?? "不明なアーティスト"
        let signature = "\(currentSongID)|\(goalText)|\(lyrics)"
        guard signature != lastKeywordSignature else { return }
        lastKeywordSignature = signature
        keywordExtractionTask?.cancel()
        extractedKeywords = []
        selectedKeywordIDs.removeAll()
        focusedKeyword = nil
        updateKeywordStatus("この曲からおすすめ単語を抽出しています...")

        keywordExtractionTask = Task { [weak self] in
            guard let self else { return }
            let result = try? await self.keywordExtractor.extractKeywords(
                from: lyrics,
                goalText: goalText,
                songTitle: songTitle,
                artistName: artistName
            )
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.extractedKeywords = Array((result ?? []).prefix(12))
                self.selectedKeywordIDs = self.selectedKeywordIDs.intersection(Set(self.extractedKeywords.map(\.id)))
                if let focusedKeyword = self.focusedKeyword, !self.extractedKeywords.contains(focusedKeyword) {
                    self.focusedKeyword = nil
                }
                let message = self.extractedKeywords.isEmpty
                    ? "この曲からおすすめ単語を見つけられませんでした"
                    : "タップで選択、長押しで意味と歌詞の元行を表示できます"
                self.updateKeywordStatus(message)
                self.renderKeywords()
                self.updateAddKeywordsButton()
                self.renderLyrics()
            }
        }
    }

    private func renderKeywords() {
        keywordButtons.forEach { button in
            keywordStackView.removeArrangedSubview(button)
            button.removeFromSuperview()
        }
        keywordButtons.removeAll()

        guard !extractedKeywords.isEmpty else {
            return
        }

        for keyword in extractedKeywords {
            let button = FilterChipButton(frame: .zero)
            button.apply(title: keyword.word, selected: selectedKeywordIDs.contains(keyword.id))
            button.addAction(UIAction { [weak self] _ in
                self?.handleKeywordTap(keyword)
            }, for: .touchUpInside)
            let press = UILongPressGestureRecognizer(target: self, action: #selector(handleKeywordLongPress(_:)))
            press.minimumPressDuration = 0.35
            button.addGestureRecognizer(press)
            button.accessibilityHint = "タップで選択、長押しで詳細"
            keywordStackView.addArrangedSubview(button)
            keywordButtons.append(button)
        }
    }

    private func handleKeywordTap(_ keyword: ExtractedKeyword) {
        focusedKeyword = keyword
        if selectedKeywordIDs.contains(keyword.id) {
            selectedKeywordIDs.remove(keyword.id)
        } else {
            selectedKeywordIDs.insert(keyword.id)
        }
        renderKeywords()
        updateAddKeywordsButton()
        renderLyrics()
        scrollToKeywordSourceLine(keyword)
    }

    @objc private func handleKeywordLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began,
              let button = gesture.view as? FilterChipButton,
              let index = keywordButtons.firstIndex(of: button),
              index < extractedKeywords.count else {
            return
        }
        presentKeywordDetail(extractedKeywords[index])
    }

    private func scrollToKeywordSourceLine(_ keyword: ExtractedKeyword) {
        guard view.window != nil else { return }
        guard let index = playbackController.currentLyrics.firstIndex(where: { $0.text == keyword.sourceLine || $0.text.localizedCaseInsensitiveContains(keyword.word) }) else {
            return
        }
        let prefix = playbackController.currentLyrics.prefix(index).map(\.text).joined(separator: "\n\n")
        let location = prefix.isEmpty ? 0 : (prefix as NSString).length + 2
        let lineLength = (playbackController.currentLyrics[index].text as NSString).length
        lyricsTextView.scrollRangeToVisible(NSRange(location: location, length: lineLength))
    }

    private func highlightKeywords(in attributed: NSMutableAttributedString, line: String, lineRange: NSRange, activeIndex: Bool, selectedLine: Bool) {
        let palette = ThemeManager.palette()
        let nsLine = line as NSString
        let searchBase = line.lowercased()

        for keyword in extractedKeywords where searchBase.contains(keyword.word.lowercased()) {
            var searchRange = NSRange(location: 0, length: nsLine.length)
            while true {
                let found = nsLine.range(of: keyword.word, options: [.caseInsensitive], range: searchRange)
                guard found.location != NSNotFound else { break }
                let globalRange = NSRange(location: lineRange.location + found.location, length: found.length)
                attributed.addAttributes([
                    .font: AppFont.jp(size: activeIndex ? 18 : 16, weight: .bold),
                    .backgroundColor: selectedLine
                        ? palette.accentStrong.withAlphaComponent(0.38)
                        : palette.accent.withAlphaComponent(0.18)
                ], range: globalRange)
                let nextLocation = found.location + found.length
                guard nextLocation < nsLine.length else { break }
                searchRange = NSRange(location: nextLocation, length: nsLine.length - nextLocation)
            }
        }
    }

    private func updateKeywordStatus(_ message: String) {
        guard keywordStatusMessage != message else { return }
        keywordStatusMessage = message
        keywordStatusLabel.text = message
    }

    private func updateAddKeywordsButton() {
        let count = selectedKeywordIDs.count
        let title = count > 0
            ? "選択した単語をセットに追加 (\(count))"
            : "選択した単語をセットに追加"
        addKeywordsButton.setTitle(title, for: .normal)
        addKeywordsButton.isEnabled = count > 0
    }

    private var isCompactWidth: Bool {
        view.bounds.width < 390
    }

    private func updateResponsiveLayout() {
        let compact = isCompactWidth

        recommendationMediaStack.axis = compact ? .vertical : .horizontal
        recommendationMediaStack.alignment = compact ? .center : .top
        recommendationTextStack.alignment = compact ? .center : .fill
        recommendationTitleLabel.textAlignment = compact ? .center : .natural
        recommendationArtistLabel.textAlignment = compact ? .center : .natural
        recommendationPlayButton.contentHorizontalAlignment = compact ? .center : .center
        recommendationArtworkWidthConstraint?.constant = compact ? 84 : 96

        playlistHeaderStack.axis = compact ? .vertical : .horizontal
        playlistHeaderStack.alignment = compact ? .fill : .center
        playlistHeaderSpacer.isHidden = compact
        playlistControlsStack.axis = compact ? .vertical : .horizontal
        playlistControlsStack.alignment = compact ? .fill : .center
        playlistControlsSpacer.isHidden = compact
        shuffleInfoStack.alignment = .center

        nowPlayingMediaStack.axis = compact ? .vertical : .horizontal
        nowPlayingMediaStack.alignment = compact ? .center : .top
        nowPlayingTextStack.alignment = compact ? .center : .fill
        nowPlayingTitleLabel.textAlignment = compact ? .center : .natural
        nowPlayingArtistLabel.textAlignment = compact ? .center : .natural
        playbackButtonsStack.spacing = compact ? AppSpacing.s(8) : AppSpacing.s(10)
        nowPlayingArtworkWidthConstraint?.constant = compact ? 64 : 72

        lyricsHeightConstraint?.constant = min(max(view.bounds.height * (compact ? 0.28 : 0.32), 220), 320)
        updateTracksTableHeight()
    }

    private func updateArtwork(_ url: URL?, into imageView: UIImageView, task: inout Task<Void, Never>?, previousURL: inout URL?) {
        guard previousURL != url else { return }
        previousURL = url
        task?.cancel()
        if url == nil {
            UIView.performWithoutAnimation {
                imageView.image = nil
                imageView.layoutIfNeeded()
            }
            return
        }
        guard let url else { return }
        task = Task { [weak imageView] in
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let image = UIImage(data: data),
                  !Task.isCancelled else { return }
            await MainActor.run {
                UIView.performWithoutAnimation {
                    imageView?.image = image
                    imageView?.layoutIfNeeded()
                }
            }
        }
    }

    private func selectedKeywordsInDisplayOrder() -> [ExtractedKeyword] {
        extractedKeywords.filter { selectedKeywordIDs.contains($0.id) }
    }

    private func presentKeywordDetail(_ keyword: ExtractedKeyword) {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = AppSpacing.s(10)

        let meaningLabel = UILabel()
        meaningLabel.applyMankiTextStyle(.body, color: ThemeManager.palette().text, numberOfLines: 0)
        meaningLabel.text = "英語の意味: \(keyword.meaning)"

        let japaneseLabel = UILabel()
        japaneseLabel.applyMankiTextStyle(.body, color: ThemeManager.palette().text, numberOfLines: 0)
        japaneseLabel.text = "日本語: \(keyword.japaneseMeaning)"

        let reasonLabel = UILabel()
        reasonLabel.applyMankiTextStyle(.caption, color: ThemeManager.palette().mutedText, numberOfLines: 0)
        reasonLabel.text = "理由: \(keyword.reason)"

        let sourceLabel = UILabel()
        sourceLabel.applyMankiTextStyle(.caption, color: ThemeManager.palette().mutedText, numberOfLines: 0)
        sourceLabel.text = "歌詞: \(keyword.sourceLine)"

        [meaningLabel, japaneseLabel, reasonLabel, sourceLabel].forEach {
            stack.addArrangedSubview($0)
        }

        let selectTitle = selectedKeywordIDs.contains(keyword.id) ? "選択解除" : "この単語を選択"
        presentUnifiedModal(
            title: keyword.word,
            message: nil,
            contentView: stack,
            actions: [
                UnifiedModalAction(title: selectTitle) { [weak self] in
                    self?.handleKeywordTap(keyword)
                },
                UnifiedModalAction(title: "閉じる", style: .cancel)
            ]
        )
    }

    @objc private func addSelectedKeywordsTapped() {
        let keywords = selectedKeywordsInDisplayOrder()
        guard !keywords.isEmpty else {
            presentUnifiedModal(
                title: "単語未選択",
                message: "追加する単語を選んでください",
                actions: [UnifiedModalAction(title: "OK")]
            )
            return
        }

        presentUnifiedModal(
            title: "セットに追加",
            message: "追加先を選んでください",
            actions: [
                UnifiedModalAction(title: "既存セットに追加") { [weak self] in
                    self?.presentExistingSetChooser(for: keywords)
                },
                UnifiedModalAction(title: "新しいセットを作って追加") { [weak self] in
                    self?.presentCreateSetPrompt(for: keywords)
                },
                UnifiedModalAction(title: "キャンセル", style: .cancel)
            ]
        )
    }

    private func presentExistingSetChooser(for keywords: [ExtractedKeyword]) {
        let sets = SetStore.loadSets()
        guard !sets.isEmpty else {
            presentUnifiedModal(
                title: "セットがありません",
                message: "既存セットがないため、新しいセットを作成してください。",
                actions: [
                    UnifiedModalAction(title: "新しいセットを作る") { [weak self] in
                        self?.presentCreateSetPrompt(for: keywords)
                    },
                    UnifiedModalAction(title: "キャンセル", style: .cancel)
                ]
            )
            return
        }

        let actions = sets.map { set in
            UnifiedModalAction(title: sanitizedSetName(set.name)) { [weak self] in
                self?.saveKeywords(keywords, intoExistingSetID: set.id)
            }
        } + [UnifiedModalAction(title: "キャンセル", style: .cancel)]

        presentUnifiedModal(
            title: "追加先のセットを選択",
            message: nil,
            actions: actions
        )
    }

    private func presentCreateSetPrompt(for keywords: [ExtractedKeyword]) {
        let textField = UITextField()
        textField.borderStyle = .roundedRect
        textField.placeholder = "セット名"
        let defaultName = "\(playbackController.currentSong?.title ?? "この曲") からの単語"
        textField.text = defaultName
        presentUnifiedModal(
            title: "新しいセットを作成",
            message: nil,
            contentView: textField,
            actions: [
                UnifiedModalAction(title: "キャンセル", style: .cancel),
                UnifiedModalAction(title: "作成して追加") { [weak self] in
                    let name = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    self?.saveKeywords(keywords, intoNewSetNamed: name.isEmpty ? defaultName : name)
                }
            ]
        )
    }

    private func saveKeywords(_ keywords: [ExtractedKeyword], intoExistingSetID setID: String) {
        let storage = JsonVocabStorage()
        var savedWords = storage.loadAll()
        var sets = SetStore.loadSets()
        guard let setIndex = sets.firstIndex(where: { $0.id == setID }) else {
            presentUnifiedModal(
                title: "保存できません",
                message: "追加先のセットを選んでください",
                actions: [UnifiedModalAction(title: "OK")]
            )
            return
        }

        let result = persistKeywords(keywords, savedWords: &savedWords, set: &sets[setIndex])
        storage.saveAll(savedWords)
        SetStore.saveSets(sets)
        presentSaveResultAlert(addedCount: result.addedCount, skippedCount: result.skippedCount)
    }

    private func saveKeywords(_ keywords: [ExtractedKeyword], intoNewSetNamed name: String) {
        let storage = JsonVocabStorage()
        var savedWords = storage.loadAll()
        var newSet = SavedSet(name: name, wordIDs: [])
        let result = persistKeywords(keywords, savedWords: &savedWords, set: &newSet)
        var sets = SetStore.loadSets()
        sets.append(newSet)
        storage.saveAll(savedWords)
        SetStore.saveSets(sets)
        presentSaveResultAlert(addedCount: result.addedCount, skippedCount: result.skippedCount)
    }

    private func persistKeywords(_ keywords: [ExtractedKeyword], savedWords: inout [SavedWord], set: inout SavedSet) -> (addedCount: Int, skippedCount: Int) {
        var addedCount = 0
        var skippedCount = 0

        for keyword in keywords {
            let wordID: String
            if let existingIndex = savedWords.firstIndex(where: { $0.english.caseInsensitiveCompare(keyword.word) == .orderedSame }) {
                wordID = savedWords[existingIndex].id
            } else {
                let savedWord = keyword.asSavedWord()
                savedWords.append(savedWord)
                wordID = savedWord.id
            }

            if set.wordIDs.contains(wordID) {
                skippedCount += 1
                continue
            }

            set.wordIDs.append(wordID)
            addedCount += 1
        }

        return (addedCount, skippedCount)
    }

    private func presentSaveResultAlert(addedCount: Int, skippedCount: Int) {
        let message: String
        if addedCount == 0 {
            message = "選択した単語はすべて追加済みでした"
        } else if skippedCount == 0 {
            message = "\(addedCount)個の単語をセットに追加しました"
        } else {
            message = "\(addedCount)個の単語をセットに追加しました\n\(skippedCount)個は重複のため追加しませんでした"
        }

        presentUnifiedModal(
            title: "追加しました",
            message: message,
            actions: [UnifiedModalAction(title: "OK")]
        )
    }

    private func sanitizedSetName(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "名称未設定" : trimmed
    }

    @objc private func authorizeTapped() {
        Task { await bootstrap() }
    }

    @objc private func playRecommendationTapped() {
        Task { await playbackController.playRecommendedSong() }
    }

    @objc private func selectPlaylistTapped() {
        let playlists = playbackController.libraryPlaylists
        guard !playlists.isEmpty else {
            presentUnifiedModal(
                title: "No Playlists",
                message: "No Apple Music library playlists were found.",
                actions: [UnifiedModalAction(title: "OK")]
            )
            return
        }

        let actions = playlists.map { snapshot in
            UnifiedModalAction(title: snapshot.title) { [weak self] in
                self?.playbackController.selectPlaylist(snapshot)
            }
        } + [UnifiedModalAction(title: "Cancel", style: .cancel)]

        presentUnifiedModal(
            title: "Select Playlist",
            message: "Choose a playlist from your Apple Music library.",
            actions: actions
        )
    }

    @objc private func shuffleChanged() {
        playbackController.shuffleEnabled = shuffleSwitch.isOn
    }

    @objc private func playAllTapped() {
        Task { await playbackController.playSelectedPlaylist(startingAt: nil) }
    }

    @objc private func previousTapped() {
        Task { await playbackController.skipPrevious() }
    }

    @objc private func playPauseTapped() {
        Task { await playbackController.togglePlayback() }
    }

    @objc private func nextTapped() {
        Task { await playbackController.skipNext() }
    }
}

extension MusicKitPlayerViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        max(playbackController.playlistTracks.count, 1)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: MusicKitTrackCell.reuseIdentifier, for: indexPath) as! MusicKitTrackCell
        if playbackController.playlistTracks.isEmpty {
            cell.configurePlaceholder(title: "No tracks", subtitle: "Select a playlist to load its tracks.")
        } else {
            let song = playbackController.playlistTracks[indexPath.row]
            let isCurrent = playbackController.currentSong?.id == song.id
            cell.configure(song: song, index: indexPath.row + 1, isCurrent: isCurrent)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.row < playbackController.playlistTracks.count else { return }
        let song = playbackController.playlistTracks[indexPath.row]
        Task { await playbackController.playSelectedPlaylist(startingAt: song) }
    }
}

@MainActor
final class MusicKitPlaybackController {
    struct LibraryPlaylistSnapshot: Hashable {
        let playlist: MusicKit.Playlist
        let songs: [Song]

        var title: String {
            playlist.name
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(playlist.id.rawValue)
        }

        static func == (lhs: LibraryPlaylistSnapshot, rhs: LibraryPlaylistSnapshot) -> Bool {
            lhs.playlist.id == rhs.playlist.id
        }
    }

    var onStateChange: (() -> Void)?

    private let player = ApplicationMusicPlayer.shared
    private var playbackTimer: Timer?
    private var queuedSongsByID: [String: Song] = [:]

    private(set) var isAuthorized = false
    private(set) var canPlayCatalogContent = false
    private(set) var statusMessage = "Authorizing Apple Music..."
    private(set) var recommendedSong: Song?
    private(set) var libraryPlaylists: [LibraryPlaylistSnapshot] = []
    private(set) var selectedPlaylist: LibraryPlaylistSnapshot?
    private(set) var playlistTracks: [Song] = []
    private(set) var currentSong: Song?
    private(set) var currentLyrics: [TimedLyricLine] = []
    private(set) var activeLyricLineIndex: Int = -1
    private(set) var lyricsNotice = "Lyrics will appear when licensed local lyric timing is available."
    var shuffleEnabled = false

    var isPlaying: Bool {
        player.state.playbackStatus == .playing
    }

    var canControlPlayback: Bool {
        currentSong != nil
    }

    deinit {
        playbackTimer?.invalidate()
    }

    func requestAuthorizationIfNeeded() async {
        let authStatus = await MusicAuthorization.request()
        isAuthorized = authStatus == .authorized

        guard isAuthorized else {
            canPlayCatalogContent = false
            statusMessage = "Apple Music authorization was denied. Enable Media & Apple Music access in Settings."
            notify()
            return
        }

        do {
            let subscription = try await MusicSubscription.current
            canPlayCatalogContent = subscription.canPlayCatalogContent
            statusMessage = subscription.canPlayCatalogContent
                ? "Connected to Apple Music."
                : "Authorized, but this Apple ID can't play catalog content."
        } catch {
            canPlayCatalogContent = false
            statusMessage = "Authorized, but subscription status couldn't be verified."
        }

        notify()
    }

    func loadInitialData() async {
        guard isAuthorized else { return }
        do {
            try configureAudioSession()
        } catch {
            statusMessage = "Audio session setup failed."
        }
        async let recommendation = fetchRecommendedSong()
        async let playlists = fetchLibraryPlaylists()
        recommendedSong = await recommendation
        libraryPlaylists = await playlists
        if let first = libraryPlaylists.first {
            selectPlaylist(first)
        }
        statusMessage = recommendedSong == nil
            ? "Connected. Recommendation fallback is unavailable right now."
            : statusMessage
        startPlaybackTimer()
        notify()
    }

    func selectPlaylist(_ snapshot: LibraryPlaylistSnapshot) {
        selectedPlaylist = snapshot
        playlistTracks = snapshot.songs
        notify()
    }

    func playRecommendedSong() async {
        guard let song = recommendedSong else { return }
        await playQueue([song], startingAt: song)
    }

    func playSelectedPlaylist(startingAt song: Song?) async {
        guard !playlistTracks.isEmpty else { return }
        let queueSongs = orderedQueueSongs(startingAt: song)
        await playQueue(queueSongs, startingAt: queueSongs.first)
    }

    func togglePlayback() async {
        if isPlaying {
            player.pause()
            statusMessage = "Paused."
            notify()
            return
        }

        guard canControlPlayback else { return }
        do {
            try configureAudioSession()
            try await player.prepareToPlay()
            try await player.play()
            statusMessage = "Playing."
        } catch {
            statusMessage = "Playback failed: \(error.localizedDescription)"
        }
        notify()
    }

    func skipNext() async {
        do {
            try await player.skipToNextEntry()
        } catch {
            statusMessage = "Couldn't skip to the next track."
        }
        syncCurrentEntry()
        notify()
    }

    func skipPrevious() async {
        do {
            try await player.skipToPreviousEntry()
        } catch {
            player.restartCurrentEntry()
        }
        syncCurrentEntry()
        notify()
    }

    private func fetchRecommendedSong() async -> Song? {
        do {
            let request = MusicCatalogChartsRequest(
                kinds: [.dailyGlobalTop],
                types: [Song.self]
            )
            let response = try await request.response()
            if let chart = response.songCharts.first,
               let song = chart.items.first {
                return song
            }
        } catch {
            statusMessage = "Charts request failed. Falling back to Today's Hits."
        }

        do {
            var search = MusicCatalogSearchRequest(term: "Today's Hits", types: [MusicKit.Playlist.self])
            search.limit = 5
            let response = try await search.response()
            guard let playlist = response.playlists.first else { return nil }
            let detailed = try await playlist.with([.tracks])
            guard let track = detailed.tracks?.first else { return nil }
            if case .song(let song) = track {
                return song
            }
        } catch {
            statusMessage = "Recommendation fallback failed."
        }

        return nil
    }

    private func fetchLibraryPlaylists() async -> [LibraryPlaylistSnapshot] {
        do {
            var request = MusicLibraryRequest<MusicKit.Playlist>()
            request.limit = 25
            let response = try await request.response()
            var snapshots: [LibraryPlaylistSnapshot] = []
            for playlist in response.items {
                let detailed = try await playlist.with([.tracks])
                let songs: [Song] = detailed.tracks?.compactMap { track in
                    if case .song(let song) = track {
                        return song
                    }
                    return nil
                } ?? []
                snapshots.append(LibraryPlaylistSnapshot(playlist: playlist, songs: songs))
            }
            return snapshots
        } catch {
            statusMessage = "Couldn't load library playlists."
            return []
        }
    }

    private func playQueue(_ songs: [Song], startingAt song: Song?) async {
        guard canPlayCatalogContent else {
            statusMessage = "This Apple Music account can't play catalog content."
            notify()
            return
        }

        guard !songs.isEmpty else { return }

        do {
            try configureAudioSession()
            queuedSongsByID = Dictionary(uniqueKeysWithValues: songs.map { ($0.id.rawValue, $0) })
            player.stop()
            player.queue = .init(for: songs, startingAt: song)
            try await player.prepareToPlay()
            try await player.play()
            statusMessage = "Playing \(song?.title ?? songs.first?.title ?? "music")."
            syncCurrentEntry()
        } catch {
            statusMessage = "Playback failed: \(error.localizedDescription)"
        }

        notify()
    }

    private func orderedQueueSongs(startingAt song: Song?) -> [Song] {
        guard !shuffleEnabled else {
            if let song {
                let rest = playlistTracks.filter { $0.id != song.id }.shuffled()
                return [song] + rest
            }
            return playlistTracks.shuffled()
        }

        guard let song,
              let index = playlistTracks.firstIndex(where: { $0.id == song.id }) else {
            return playlistTracks
        }

        return Array(playlistTracks[index...]) + Array(playlistTracks[..<index])
    }

    private func configureAudioSession() throws {
        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
        try AVAudioSession.sharedInstance().setActive(true)
    }

    private func startPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.syncCurrentEntry()
                self.notify()
            }
        }
    }

    private func syncCurrentEntry() {
        guard let entry = player.queue.currentEntry,
              let item = entry.item else {
            currentSong = nil
            currentLyrics = []
            activeLyricLineIndex = -1
            lyricsNotice = "Play a song to view lyrics."
            return
        }

        let currentID = item.id.rawValue
        if currentSong?.id.rawValue != currentID {
            currentSong = resolveSong(from: item)
            loadLyrics(for: currentSong)
        }

        let playbackTime = player.playbackTime
        activeLyricLineIndex = currentLyrics.lastIndex(where: { $0.time <= playbackTime }) ?? (currentLyrics.isEmpty ? -1 : 0)
    }

    private func resolveSong(from item: MusicKit.MusicPlayer.Queue.Entry.Item) -> Song? {
        switch item {
        case .song(let song):
            return song
        case .musicVideo:
            return nil
        @unknown default:
            return queuedSongsByID[item.id.rawValue]
        }
    }

    private func loadLyrics(for song: Song?) {
        guard let song else {
            currentLyrics = []
            lyricsNotice = "Play a song to view lyrics."
            return
        }

        let mankiSong = MankiSong(from: song)
        let repositoryLyrics = LyricsRepository.shared.lyrics(for: mankiSong)
        if !repositoryLyrics.isEmpty {
            currentLyrics = repositoryLyrics
            lyricsNotice = "Synced local lyric timing is displayed for the current song."
            return
        }

        if !mankiSong.timedLyrics.isEmpty {
            currentLyrics = mankiSong.timedLyrics
            lyricsNotice = "Synced lyrics are displayed from the app's local lyric store."
            return
        }

        if !mankiSong.lyricsLines.isEmpty {
            currentLyrics = mankiSong.lyricsLines.enumerated().map { index, text in
                TimedLyricLine(time: Double(index) * 3.5, text: text, japaneseTranslation: "")
            }
            lyricsNotice = "Static local lyrics are displayed because synced timing isn't available."
            return
        }

        currentLyrics = []
        lyricsNotice = song.hasLyrics
            ? "Apple's MusicKit exposes whether lyrics exist, but not the lyric text itself. Use your own licensed lyric source for this track."
            : "No lyrics are available for the current track."
    }

    private func notify() {
        onStateChange?()
    }
}

private final class MusicKitTrackCell: UITableViewCell {
    static let reuseIdentifier = "MusicKitTrackCell"

    private let cardView = UIView()
    private let indexLabel = UILabel()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

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

        [cardView, indexLabel, titleLabel, subtitleLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        contentView.addSubview(cardView)
        [indexLabel, titleLabel, subtitleLabel].forEach { cardView.addSubview($0) }

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: AppSpacing.s(4)),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AppSpacing.s(4)),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -AppSpacing.s(4)),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -AppSpacing.s(4)),

            indexLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: AppSpacing.s(12)),
            indexLabel.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            indexLabel.widthAnchor.constraint(equalToConstant: 28),

            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: AppSpacing.s(10)),
            titleLabel.leadingAnchor.constraint(equalTo: indexLabel.trailingAnchor, constant: AppSpacing.s(10)),
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -AppSpacing.s(12)),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: AppSpacing.s(4)),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            subtitleLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -AppSpacing.s(10))
        ])
    }

    func configure(song: Song, index: Int, isCurrent: Bool) {
        let palette = ThemeManager.palette()
        ThemeManager.styleCard(
            cardView,
            fillColor: isCurrent ? palette.surfaceAlt.withAlphaComponent(0.92) : palette.surface.withAlphaComponent(0.9)
        )
        indexLabel.applyMankiTextStyle(.caption, color: palette.mutedText, numberOfLines: 1)
        titleLabel.applyMankiTextStyle(.body, color: palette.text, numberOfLines: 2)
        subtitleLabel.applyMankiTextStyle(.caption, color: palette.mutedText, numberOfLines: 1)
        indexLabel.text = "\(index)."
        titleLabel.text = song.title
        subtitleLabel.text = song.artistName
    }

    func configurePlaceholder(title: String, subtitle: String) {
        let palette = ThemeManager.palette()
        ThemeManager.styleCard(cardView, fillColor: palette.surface.withAlphaComponent(0.9))
        indexLabel.applyMankiTextStyle(.caption, color: palette.mutedText, numberOfLines: 1)
        titleLabel.applyMankiTextStyle(.body, color: palette.text, numberOfLines: 2)
        subtitleLabel.applyMankiTextStyle(.caption, color: palette.mutedText, numberOfLines: 1)
        indexLabel.text = "-"
        titleLabel.text = title
        subtitleLabel.text = subtitle
    }
}
