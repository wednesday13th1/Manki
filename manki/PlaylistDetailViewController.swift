import UIKit

final class PlaylistDetailViewController: BaseViewController {
    private let playlistID: String
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let headerStack = UIStackView()
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let metaLabel = UILabel()
    private let themeBadge = EmotionBadgeLabel()
    private let reviewButton = UIButton(type: .system)
    private let quizButton = UIButton(type: .system)
    private let appleMusicButton = UIButton(type: .system)
    private let filterScrollView = UIScrollView()
    private let filterStack = UIStackView()
    private let difficultyScrollView = UIScrollView()
    private let difficultyStack = UIStackView()
    private let emptyLabel = UILabel()

    private var playlist: Playlist?
    private var selectedEmotion: EmotionTag?
    private var selectedDifficulty: PlaylistCardDifficulty?
    private var emotionButtons: [FilterChipButton] = []
    private var difficultyButtons: [FilterChipButton] = []

    init(playlistID: String) {
        self.playlistID = playlistID
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Playlist詳細"
        configureUI()
        reloadPlaylist()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadPlaylist()
        tableView.reloadData()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateHeaderLayout()
    }

    override func applyBaseTheme() {
        super.applyBaseTheme()
        let palette = ThemeManager.palette()
        [titleLabel, descriptionLabel, metaLabel, emptyLabel].forEach {
            $0.textColor = palette.text
        }
        descriptionLabel.textColor = palette.mutedText
        metaLabel.textColor = palette.mutedText
        emptyLabel.textColor = palette.mutedText
        ThemeManager.stylePrimaryButton(reviewButton)
        ThemeManager.styleSecondaryButton(quizButton)
        ThemeManager.styleSecondaryButton(appleMusicButton)
        themeBadge.apply(tag: playlist?.emotionTheme ?? .sad, palette: palette)
        updateFilterButtons()
    }

    private func configureUI() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "曲追加",
            style: .plain,
            target: self,
            action: #selector(addSong)
        )

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(RetroSummaryCell.self, forCellReuseIdentifier: RetroSummaryCell.reuseIdentifier)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 112
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear

        headerStack.axis = .vertical
        headerStack.spacing = AppSpacing.s(12)
        headerStack.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.numberOfLines = 0
        descriptionLabel.numberOfLines = 0
        metaLabel.numberOfLines = 0
        emptyLabel.numberOfLines = 0
        emptyLabel.textAlignment = .center
        emptyLabel.text = "この Playlist にまだ曲がありません。"

        let titleRow = UIStackView(arrangedSubviews: [titleLabel, themeBadge])
        titleRow.axis = .horizontal
        titleRow.alignment = .center
        titleRow.spacing = AppSpacing.s(10)

        let buttonRow = UIStackView(arrangedSubviews: [reviewButton, quizButton])
        buttonRow.axis = .horizontal
        buttonRow.spacing = AppSpacing.s(12)
        buttonRow.distribution = .fillEqually

        reviewButton.setTitle("このPlaylistを復習", for: .normal)
        quizButton.setTitle("クイズ開始", for: .normal)
        appleMusicButton.setTitle("Apple Musicから曲を追加", for: .normal)
        reviewButton.addTarget(self, action: #selector(openReviewMenu), for: .touchUpInside)
        quizButton.addTarget(self, action: #selector(openQuiz), for: .touchUpInside)
        appleMusicButton.addTarget(self, action: #selector(addSongFromAppleMusic), for: .touchUpInside)

        filterScrollView.showsHorizontalScrollIndicator = false
        filterScrollView.translatesAutoresizingMaskIntoConstraints = false
        filterStack.axis = .horizontal
        filterStack.spacing = AppSpacing.s(8)
        filterStack.translatesAutoresizingMaskIntoConstraints = false
        filterScrollView.addSubview(filterStack)

        difficultyScrollView.showsHorizontalScrollIndicator = false
        difficultyScrollView.translatesAutoresizingMaskIntoConstraints = false
        difficultyStack.axis = .horizontal
        difficultyStack.spacing = AppSpacing.s(8)
        difficultyStack.translatesAutoresizingMaskIntoConstraints = false
        difficultyScrollView.addSubview(difficultyStack)

        headerStack.addArrangedSubview(titleRow)
        headerStack.addArrangedSubview(descriptionLabel)
        headerStack.addArrangedSubview(metaLabel)
        headerStack.addArrangedSubview(buttonRow)
        headerStack.addArrangedSubview(appleMusicButton)
        headerStack.addArrangedSubview(makeSectionLabel("感情タグで絞り込み"))
        headerStack.addArrangedSubview(filterScrollView)
        headerStack.addArrangedSubview(makeSectionLabel("難易度で絞り込み"))
        headerStack.addArrangedSubview(difficultyScrollView)

        let container = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 280))
        container.addSubview(headerStack)
        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: container.topAnchor, constant: AppSpacing.s(16)),
            headerStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: AppSpacing.s(16)),
            headerStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -AppSpacing.s(16)),
            headerStack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -AppSpacing.s(12)),

            filterStack.topAnchor.constraint(equalTo: filterScrollView.topAnchor),
            filterStack.leadingAnchor.constraint(equalTo: filterScrollView.leadingAnchor),
            filterStack.trailingAnchor.constraint(equalTo: filterScrollView.trailingAnchor),
            filterStack.bottomAnchor.constraint(equalTo: filterScrollView.bottomAnchor),
            filterStack.heightAnchor.constraint(equalTo: filterScrollView.heightAnchor),

            difficultyStack.topAnchor.constraint(equalTo: difficultyScrollView.topAnchor),
            difficultyStack.leadingAnchor.constraint(equalTo: difficultyScrollView.leadingAnchor),
            difficultyStack.trailingAnchor.constraint(equalTo: difficultyScrollView.trailingAnchor),
            difficultyStack.bottomAnchor.constraint(equalTo: difficultyScrollView.bottomAnchor),
            difficultyStack.heightAnchor.constraint(equalTo: difficultyScrollView.heightAnchor),

            filterScrollView.heightAnchor.constraint(equalToConstant: AppSpacing.s(58)),
            difficultyScrollView.heightAnchor.constraint(equalToConstant: AppSpacing.s(58))
        ])
        tableView.tableHeaderView = container

        view.addSubview(tableView)
        view.addSubview(emptyLabel)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        rebuildFilterButtons()
    }

    private func makeSectionLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.applyMankiTextStyle(.sectionTitle, color: ThemeManager.palette().text, numberOfLines: 1)
        label.text = text
        return label
    }

    private func reloadPlaylist() {
        playlist = PlaylistStore.loadPlaylists().first(where: { $0.id == playlistID })
        guard let playlist else { return }
        titleLabel.applyMankiTextStyle(.screenTitle, color: ThemeManager.palette().text, numberOfLines: 0)
        descriptionLabel.applyMankiTextStyle(.body, color: ThemeManager.palette().mutedText, numberOfLines: 0)
        metaLabel.applyMankiTextStyle(.caption, color: ThemeManager.palette().mutedText, numberOfLines: 0)
        titleLabel.text = playlist.title
        descriptionLabel.text = playlist.description.isEmpty ? "好きな曲・気分・フレーズから覚える Playlist" : playlist.description
        metaLabel.text = "\(playlist.songs.count)曲 / \(filteredCards().count)カード / theme: \(playlist.emotionTheme.displayName)"
        themeBadge.apply(tag: playlist.emotionTheme, palette: ThemeManager.palette())
        updateHeaderLayout()
        emptyLabel.text = filteredSongs().isEmpty ? "条件に一致する曲がありません。" : ""
        emptyLabel.isHidden = !filteredSongs().isEmpty
        tableView.reloadData()
    }

    private func updateHeaderLayout() {
        guard let header = tableView.tableHeaderView else { return }
        let width = tableView.bounds.width == 0 ? view.bounds.width : tableView.bounds.width
        header.frame.size.width = width
        header.layoutIfNeeded()
        let size = header.systemLayoutSizeFitting(CGSize(width: width, height: UIView.layoutFittingCompressedSize.height))
        header.frame.size.height = size.height
        tableView.tableHeaderView = header
    }

    private func rebuildFilterButtons() {
        filterStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        difficultyStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        emotionButtons.removeAll()
        difficultyButtons.removeAll()

        let allEmotionButton = makeEmotionButton(title: "ALL", emotion: nil)
        filterStack.addArrangedSubview(allEmotionButton)
        emotionButtons.append(allEmotionButton)
        EmotionTag.allCases.forEach { tag in
            let button = makeEmotionButton(title: tag.displayName, emotion: tag)
            filterStack.addArrangedSubview(button)
            emotionButtons.append(button)
        }

        let allDifficultyButton = makeDifficultyButton(title: "ALL", difficulty: nil)
        difficultyStack.addArrangedSubview(allDifficultyButton)
        difficultyButtons.append(allDifficultyButton)
        PlaylistCardDifficulty.allCases.forEach { difficulty in
            let button = makeDifficultyButton(title: difficulty.displayName, difficulty: difficulty)
            difficultyStack.addArrangedSubview(button)
            difficultyButtons.append(button)
        }
        updateFilterButtons()
    }

    private func makeEmotionButton(title: String, emotion: EmotionTag?) -> FilterChipButton {
        let button = FilterChipButton(frame: .zero)
        button.setTitle(title, for: .normal)
        button.accessibilityIdentifier = emotion?.rawValue ?? "all-emotions"
        button.addAction(UIAction { [weak self] _ in
            self?.selectedEmotion = emotion
            self?.updateFilterButtons()
            self?.reloadPlaylist()
        }, for: .touchUpInside)
        return button
    }

    private func makeDifficultyButton(title: String, difficulty: PlaylistCardDifficulty?) -> FilterChipButton {
        let button = FilterChipButton(frame: .zero)
        button.setTitle(title, for: .normal)
        button.accessibilityIdentifier = difficulty?.rawValue ?? "all-difficulties"
        button.addAction(UIAction { [weak self] _ in
            self?.selectedDifficulty = difficulty
            self?.updateFilterButtons()
            self?.reloadPlaylist()
        }, for: .touchUpInside)
        return button
    }

    private func updateFilterButtons() {
        emotionButtons.forEach { button in
            let selected = button.accessibilityIdentifier == (selectedEmotion?.rawValue ?? "all-emotions")
            button.apply(title: button.title(for: .normal) ?? "", selected: selected)
        }
        difficultyButtons.forEach { button in
            let selected = button.accessibilityIdentifier == (selectedDifficulty?.rawValue ?? "all-difficulties")
            button.apply(title: button.title(for: .normal) ?? "", selected: selected)
        }
    }

    private func filteredSongs() -> [PlaylistSong] {
        guard let playlist else { return [] }
        return playlist.songs.filter { !$0.filteredCards(emotion: selectedEmotion, difficulty: selectedDifficulty).isEmpty }
    }

    private func filteredCards() -> [PlaylistCard] {
        playlist?.filteredCards(emotion: selectedEmotion, difficulty: selectedDifficulty) ?? []
    }

    @objc private func addSong() {
        let controller = PlaylistEditorViewController(onSaveSong: { [weak self] song in
            self?.appendSong(song)
        })
        navigationController?.pushViewController(controller, animated: true)
    }

    @objc private func addSongFromAppleMusic() {
        Task { [weak self] in
            guard let self else { return }
            let access = await AppleMusicCatalogService.requestAccess()
            guard access.isAuthorized else {
                self.presentUnifiedModal(
                    title: "Apple Musicを利用できません",
                    message: access.message,
                    actions: [UnifiedModalAction(title: "OK")]
                )
                return
            }

            let controller = AppleMusicSearchViewController(
                statusMessage: access.message,
                existingAppleMusicIDs: self.currentAppleMusicIDs()
            ) { [weak self] song in
                self?.appendSong(song)
            }
            let navigationController = UINavigationController(rootViewController: controller)
            navigationController.modalPresentationStyle = .pageSheet
            if let sheet = navigationController.sheetPresentationController {
                sheet.detents = [.medium(), .large()]
                sheet.prefersGrabberVisible = true
            }
            self.present(navigationController, animated: true)
        }
    }

    @objc private func openQuiz() {
        let words = filteredCards().map { $0.asSavedWord() }
        guard !words.isEmpty else {
            presentUnifiedModal(title: "復習対象なし", message: "フィルターに一致するカードがありません。", actions: [UnifiedModalAction(title: "OK")])
            return
        }
        let controller = TestViewController()
        controller.presetWords = words
        navigationController?.pushViewController(controller, animated: true)
    }

    @objc private func openReviewMenu() {
        let words = filteredCards().map { $0.asSavedWord() }
        guard !words.isEmpty else {
            presentUnifiedModal(title: "復習対象なし", message: "フィルターに一致するカードがありません。", actions: [UnifiedModalAction(title: "OK")])
            return
        }
        presentUnifiedModal(
            title: "このPlaylistを復習",
            message: "タグと難易度フィルターを反映して開始します。",
            actions: [
                UnifiedModalAction(title: "フリップ") { [weak self] in
                    let controller = FlipViewController()
                    controller.presetWords = words
                    self?.navigationController?.pushViewController(controller, animated: true)
                },
                UnifiedModalAction(title: "テスト") { [weak self] in
                    let controller = TestViewController()
                    controller.presetWords = words
                    self?.navigationController?.pushViewController(controller, animated: true)
                },
                UnifiedModalAction(title: "キャンセル", style: .cancel)
            ]
        )
    }

    private func currentAppleMusicIDs() -> Set<String> {
        Set(playlist?.songs.compactMap(\.appleMusicId) ?? [])
    }

    private func appendSong(_ song: PlaylistSong) {
        var playlists = PlaylistStore.loadPlaylists()
        guard let index = playlists.firstIndex(where: { $0.id == playlistID }) else { return }

        if let appleMusicId = song.appleMusicId,
           playlists[index].songs.contains(where: { $0.appleMusicId == appleMusicId }) {
            presentUnifiedModal(
                title: "追加済み",
                message: "この Apple Music の曲はすでに Playlist に入っています。",
                actions: [UnifiedModalAction(title: "OK")]
            )
            return
        }

        playlists[index].songs.append(song)
        PlaylistStore.savePlaylists(playlists)
        reloadPlaylist()
    }
}

extension PlaylistDetailViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filteredSongs().count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: RetroSummaryCell.reuseIdentifier, for: indexPath) as! RetroSummaryCell
        let song = filteredSongs()[indexPath.row]
        let cards = song.filteredCards(emotion: selectedEmotion, difficulty: selectedDifficulty)
        let dominantEmotion = cards.first?.emotionTag ?? playlist?.emotionTheme ?? .sad
        cell.configure(
            title: song.title,
            subtitle: song.artist,
            meta: "\(cards.count)カード",
            emotionTag: dominantEmotion
        )
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let song = filteredSongs()[indexPath.row]
        let controller = PlaylistSongViewController(
            playlistID: playlistID,
            songID: song.id,
            emotionFilter: selectedEmotion,
            difficultyFilter: selectedDifficulty
        )
        navigationController?.pushViewController(controller, animated: true)
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        true
    }

    func tableView(_ tableView: UITableView,
                   commit editingStyle: UITableViewCell.EditingStyle,
                   forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }
        let songID = filteredSongs()[indexPath.row].id
        var playlists = PlaylistStore.loadPlaylists()
        guard let playlistIndex = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        playlists[playlistIndex].songs.removeAll { $0.id == songID }
        PlaylistStore.savePlaylists(playlists)
        reloadPlaylist()
    }
}
