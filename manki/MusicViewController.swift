import UIKit

final class MusicViewController: BaseViewController {
    private enum SourceMode {
        case recent
        case ai
        case apple(title: String)

        var sectionTitle: String {
            switch self {
            case .recent:
                return "最近の曲"
            case .ai:
                return "今日のおすすめ"
            case .apple(let title):
                return title
            }
        }
    }

    private let service = MusicService()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyLabel = UILabel()
    private let headerCard = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let sectionLabel = UILabel()
    private let sectionNoteLabel = UILabel()
    private let aiButton = UIButton(type: .system)
    private let appleButton = UIButton(type: .system)
    private let createPlaylistButton = UIButton(type: .system)
    private var userPlaylists: [MankiPlaylist] = []
    private var songs: [MankiSong] = []
    private var sourceMode: SourceMode = .recent

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Music"
        configureUI()
        loadRecentSongs()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        userPlaylists = MusicPlaylistStore.shared.getPlaylists()
        if case .recent = sourceMode {
            loadRecentSongs()
        } else {
            tableView.reloadData()
        }
    }

    override func applyBaseTheme() {
        super.applyBaseTheme()
        let palette = ThemeManager.palette()
        titleLabel.applyMankiTextStyle(.screenTitle, color: palette.text, numberOfLines: 1)
        subtitleLabel.applyMankiTextStyle(.body, color: palette.mutedText, numberOfLines: 0)
        sectionLabel.applyMankiTextStyle(.sectionTitle, color: palette.text, numberOfLines: 1)
        sectionNoteLabel.applyMankiTextStyle(.caption, color: palette.mutedText, numberOfLines: 0)
        emptyLabel.applyMankiTextStyle(.body, color: palette.mutedText, alignment: .center, numberOfLines: 0)
        ThemeManager.styleCard(headerCard, fillColor: palette.surface.withAlphaComponent(0.95))
        ThemeManager.stylePrimaryButton(aiButton)
        ThemeManager.styleSecondaryButton(appleButton)
        ThemeManager.styleSecondaryButton(createPlaylistButton)
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
    }

    private func configureUI() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(MusicPlaylistCell.self, forCellReuseIdentifier: MusicPlaylistCell.reuseIdentifier)
        tableView.register(MusicSongCell.self, forCellReuseIdentifier: MusicSongCell.reuseIdentifier)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 156
        tableView.backgroundColor = .clear

        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.text = "曲を開くとここに並びます。"
        emptyLabel.isHidden = true

        headerCard.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Music"
        subtitleLabel.text = "songs that teach you words"
        subtitleLabel.textAlignment = .left
        subtitleLabel.numberOfLines = 0
        sectionLabel.text = "最近の曲"
        sectionNoteLabel.text = "音から出会った単語を、ここで拾います。"
        sectionNoteLabel.numberOfLines = 0

        aiButton.setTitle("今日のおすすめ", for: .normal)
        appleButton.setTitle("Apple Musicプレイリストを開く", for: .normal)
        createPlaylistButton.setTitle("プレイリスト作成", for: .normal)
        aiButton.addTarget(self, action: #selector(showAIRecommendations), for: .touchUpInside)
        appleButton.addTarget(self, action: #selector(openAppleMusicPlaylists), for: .touchUpInside)
        createPlaylistButton.addTarget(self, action: #selector(createPlaylistTapped), for: .touchUpInside)

        let buttonStack = UIStackView(arrangedSubviews: [aiButton, appleButton, createPlaylistButton])
        buttonStack.axis = .vertical
        buttonStack.spacing = AppSpacing.s(10)

        let headerStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, buttonStack, sectionLabel, sectionNoteLabel])
        headerStack.axis = .vertical
        headerStack.spacing = AppSpacing.s(12)
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        headerCard.addSubview(headerStack)

        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: headerCard.topAnchor, constant: AppSpacing.s(16)),
            headerStack.leadingAnchor.constraint(equalTo: headerCard.leadingAnchor, constant: AppSpacing.s(16)),
            headerStack.trailingAnchor.constraint(equalTo: headerCard.trailingAnchor, constant: -AppSpacing.s(16)),
            headerStack.bottomAnchor.constraint(equalTo: headerCard.bottomAnchor, constant: -AppSpacing.s(16))
        ])

        let headerContainer = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 220))
        headerContainer.addSubview(headerCard)
        NSLayoutConstraint.activate([
            headerCard.topAnchor.constraint(equalTo: headerContainer.topAnchor, constant: AppSpacing.s(16)),
            headerCard.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: AppSpacing.s(16)),
            headerCard.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -AppSpacing.s(16)),
            headerCard.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: -AppSpacing.s(8))
        ])
        tableView.tableHeaderView = headerContainer

        view.addSubview(tableView)
        view.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: AppSpacing.s(24)),
            emptyLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -AppSpacing.s(24))
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateHeaderLayout()
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

    private func loadRecentSongs() {
        userPlaylists = MusicPlaylistStore.shared.getPlaylists()
        sourceMode = .recent
        let recents = MusicLearningStore.recentSongs()
        songs = recents.isEmpty ? MusicMockData.aiRecommendedSongs : recents
        refreshContent(note: recents.isEmpty ? "最近開いた曲がまだないので、おすすめを表示しています。" : "最近ひらいた曲から、気になる単語を拾えます。")
    }

    private func refreshContent(note: String) {
        sectionLabel.text = sourceMode.sectionTitle
        sectionNoteLabel.text = note
        emptyLabel.isHidden = !songs.isEmpty
        tableView.reloadData()
        updateHeaderLayout()
    }

    @objc private func createPlaylistTapped() {
        let alert = UIAlertController(title: "プレイリスト作成", message: "名前を入力してください。", preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "Midnight Words"
        }
        alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel))
        alert.addAction(UIAlertAction(title: "作成", style: .default) { [weak self, weak alert] _ in
            guard let self,
                  let name = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !name.isEmpty else { return }
            let playlist = MusicPlaylistStore.shared.createPlaylist(name: name)
            self.userPlaylists = MusicPlaylistStore.shared.getPlaylists()
            self.sourceMode = .apple(title: playlist.name)
            self.songs = playlist.songs
            self.refreshContent(note: "ローカルのプレイリストを作成しました。MusicKit なしで保存されています。")
        })
        present(alert, animated: true)
    }

    @objc private func showAIRecommendations() {
        sourceMode = .ai
        songs = MusicMockData.aiRecommendedSongs
        refreshContent(note: "モックのAIおすすめプレイリストです。")
    }

    @objc private func openAppleMusicPlaylists() {
        Task { [weak self] in
            guard let self else { return }
            let permission = await service.requestAppleMusicPermission()
            guard permission.granted else {
                presentUnifiedModal(title: "Apple Music", message: permission.message, actions: [UnifiedModalAction(title: "OK")])
                return
            }

            let playlists = await service.fetchUserPlaylists()
            let actions = playlists.map { playlist in
                UnifiedModalAction(title: playlist.title) { [weak self] in
                    self?.loadAppleMusicPlaylist(playlist)
                }
            } + [UnifiedModalAction(title: "キャンセル", style: .cancel)]

            presentUnifiedModal(
                title: "Apple Musicプレイリスト",
                message: permission.message,
                actions: actions
            )
        }
    }

    private func loadAppleMusicPlaylist(_ playlist: MankiPlaylist) {
        Task { [weak self] in
            guard let self else { return }
            let loadedSongs = await service.fetchSongsFromPlaylist(playlist)
            await MainActor.run {
                self.sourceMode = .apple(title: playlist.title)
                self.songs = loadedSongs
                self.refreshContent(note: "現在はモック表示です。MusicKit 連携ポイントは `MusicService` にまとめています。")
            }
        }
    }

    private func openLyrics(for song: MankiSong, startLearning: Bool) {
        MusicLearningStore.saveRecent(song: song)
        let controller = LyricsViewController(song: song, startLearning: startLearning)
        navigationController?.pushViewController(controller, animated: true)
    }
}

extension MusicViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return max(userPlaylists.count, 1)
        }
        return songs.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: MusicPlaylistCell.reuseIdentifier) as? MusicPlaylistCell
                ?? MusicPlaylistCell(style: .default, reuseIdentifier: MusicPlaylistCell.reuseIdentifier)
            if userPlaylists.isEmpty {
                cell.configurePlaceholder()
            } else {
                cell.configure(playlist: userPlaylists[indexPath.row])
            }
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: MusicSongCell.reuseIdentifier, for: indexPath) as! MusicSongCell
        let song = songs[indexPath.row]
        cell.configure(song: song)
        cell.onLyricsTapped = { [weak self] in
            self?.openLyrics(for: song, startLearning: false)
        }
        cell.onLearnTapped = { [weak self] in
            self?.openLyrics(for: song, startLearning: true)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 0 ? "My Playlists" : sourceMode.sectionTitle
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.section == 0, !userPlaylists.isEmpty else { return }
        let playlist = userPlaylists[indexPath.row]
        sourceMode = .apple(title: playlist.name)
        songs = playlist.songs
        refreshContent(note: "作成したプレイリストです。曲はまだ空です。")
    }
}

private final class MusicPlaylistCell: UITableViewCell {
    static let reuseIdentifier = "MusicPlaylistCell"

    private let cardView = UIView()
    private let iconView = UIImageView()
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

        [cardView, iconView, titleLabel, subtitleLabel].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        contentView.addSubview(cardView)
        [iconView, titleLabel, subtitleLabel].forEach { cardView.addSubview($0) }

        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AppSpacing.s(12)),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -AppSpacing.s(12)),
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: AppSpacing.s(6)),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -AppSpacing.s(6)),

            iconView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: AppSpacing.s(14)),
            iconView.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),

            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: AppSpacing.s(12)),
            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: AppSpacing.s(10)),
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -AppSpacing.s(14)),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: AppSpacing.s(4)),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            subtitleLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -AppSpacing.s(12))
        ])
    }

    func configure(playlist: MankiPlaylist) {
        let palette = ThemeManager.palette()
        ThemeManager.styleCard(cardView, fillColor: palette.surface.withAlphaComponent(0.95))
        iconView.image = UIImage(systemName: "music.note.list")?.withTintColor(palette.text, renderingMode: .alwaysOriginal)
        titleLabel.applyMankiTextStyle(.sectionTitle, color: palette.text, numberOfLines: 1)
        subtitleLabel.applyMankiTextStyle(.caption, color: palette.mutedText, numberOfLines: 1)
        titleLabel.text = playlist.name
        subtitleLabel.text = "\(playlist.type.displayName) / \(playlist.songs.count) songs"
    }

    func configurePlaceholder() {
        let palette = ThemeManager.palette()
        ThemeManager.styleCard(cardView, fillColor: palette.surface.withAlphaComponent(0.95))
        iconView.image = UIImage(systemName: "music.note")?.withTintColor(palette.mutedText, renderingMode: .alwaysOriginal)
        titleLabel.applyMankiTextStyle(.sectionTitle, color: palette.mutedText, numberOfLines: 1)
        subtitleLabel.applyMankiTextStyle(.caption, color: palette.mutedText, numberOfLines: 1)
        titleLabel.text = "まだプレイリストがありません"
        subtitleLabel.text = "上のボタンから作成できます"
    }
}

private final class MusicSongCell: UITableViewCell {
    static let reuseIdentifier = "MusicSongCell"

    private let cardView = UIView()
    private let artworkPlaceholder = UIView()
    private let iconLabel = UILabel()
    private let moodLabel = UILabel()
    private let titleLabel = UILabel()
    private let artistLabel = UILabel()
    private let metaLabel = UILabel()
    private let lyricsButton = UIButton(type: .system)
    private let learnButton = UIButton(type: .system)

    var onLyricsTapped: (() -> Void)?
    var onLearnTapped: (() -> Void)?

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

        [cardView, artworkPlaceholder, iconLabel, moodLabel, titleLabel, artistLabel, metaLabel, lyricsButton, learnButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        artworkPlaceholder.layer.cornerRadius = 18
        artworkPlaceholder.layer.borderWidth = 2
        artworkPlaceholder.clipsToBounds = true

        iconLabel.text = "♫"
        iconLabel.textAlignment = .center
        moodLabel.textAlignment = .center

        lyricsButton.setTitle("歌詞を見る", for: .normal)
        learnButton.setTitle("この曲で学ぶ", for: .normal)
        lyricsButton.addTarget(self, action: #selector(tapLyrics), for: .touchUpInside)
        learnButton.addTarget(self, action: #selector(tapLearn), for: .touchUpInside)

        let buttonStack = UIStackView(arrangedSubviews: [lyricsButton, learnButton])
        buttonStack.axis = .horizontal
        buttonStack.spacing = AppSpacing.s(10)
        buttonStack.distribution = .fillEqually
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(cardView)
        [artworkPlaceholder, titleLabel, artistLabel, metaLabel, buttonStack].forEach { cardView.addSubview($0) }
        artworkPlaceholder.addSubview(iconLabel)
        artworkPlaceholder.addSubview(moodLabel)

        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AppSpacing.s(12)),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -AppSpacing.s(12)),
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: AppSpacing.s(8)),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -AppSpacing.s(8)),

            artworkPlaceholder.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: AppSpacing.s(14)),
            artworkPlaceholder.topAnchor.constraint(equalTo: cardView.topAnchor, constant: AppSpacing.s(14)),
            artworkPlaceholder.widthAnchor.constraint(equalToConstant: 78),
            artworkPlaceholder.heightAnchor.constraint(equalToConstant: 78),

            iconLabel.centerXAnchor.constraint(equalTo: artworkPlaceholder.centerXAnchor),
            iconLabel.topAnchor.constraint(equalTo: artworkPlaceholder.topAnchor, constant: AppSpacing.s(10)),

            moodLabel.leadingAnchor.constraint(equalTo: artworkPlaceholder.leadingAnchor, constant: AppSpacing.s(8)),
            moodLabel.trailingAnchor.constraint(equalTo: artworkPlaceholder.trailingAnchor, constant: -AppSpacing.s(8)),
            moodLabel.bottomAnchor.constraint(equalTo: artworkPlaceholder.bottomAnchor, constant: -AppSpacing.s(10)),

            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: AppSpacing.s(16)),
            titleLabel.leadingAnchor.constraint(equalTo: artworkPlaceholder.trailingAnchor, constant: AppSpacing.s(12)),
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -AppSpacing.s(14)),

            artistLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: AppSpacing.s(6)),
            artistLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            artistLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            metaLabel.topAnchor.constraint(equalTo: artistLabel.bottomAnchor, constant: AppSpacing.s(6)),
            metaLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            metaLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            buttonStack.topAnchor.constraint(equalTo: artworkPlaceholder.bottomAnchor, constant: AppSpacing.s(12)),
            buttonStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: AppSpacing.s(14)),
            buttonStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -AppSpacing.s(14)),
            buttonStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -AppSpacing.s(14))
        ])
    }

    func configure(song: MankiSong) {
        let palette = ThemeManager.palette()
        ThemeManager.styleCard(cardView, fillColor: palette.surface.withAlphaComponent(0.95))
        artworkPlaceholder.backgroundColor = palette.surfaceAlt.withAlphaComponent(0.92)
        artworkPlaceholder.layer.borderColor = palette.border.cgColor
        iconLabel.font = AppFont.jp(size: 24, weight: .bold)
        iconLabel.textColor = palette.text
        moodLabel.font = AppFont.jp(size: 11, weight: .bold)
        moodLabel.textColor = palette.mutedText
        moodLabel.text = song.mood.uppercased()
        titleLabel.applyMankiTextStyle(.sectionTitle, color: palette.text, numberOfLines: 2)
        artistLabel.applyMankiTextStyle(.body, color: palette.mutedText, numberOfLines: 1)
        metaLabel.applyMankiTextStyle(.caption, color: palette.mutedText, numberOfLines: 1)
        titleLabel.text = song.title
        artistLabel.text = song.artist
        metaLabel.text = "\(song.level.uppercased()) / \(song.keywords.count) words"
        ThemeManager.styleSecondaryButton(lyricsButton)
        ThemeManager.stylePrimaryButton(learnButton)
    }

    @objc private func tapLyrics() {
        onLyricsTapped?()
    }

    @objc private func tapLearn() {
        onLearnTapped?()
    }
}
