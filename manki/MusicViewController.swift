import UIKit
import MusicKit

final class MusicViewController: BaseViewController {
    private enum SourceMode {
        case recent
        case ai
        case localPlaylist(title: String)
        case applePlaylist(title: String)

        var sectionTitle: String {
            switch self {
            case .recent:
                return "最近の曲"
            case .ai:
                return "今日のおすすめ"
            case .localPlaylist(let title), .applePlaylist(let title):
                return title
            }
        }
    }

    private let service = MusicService.shared
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyLabel = UILabel()
    private let headerCard = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let sectionLabel = UILabel()
    private let sectionNoteLabel = UILabel()
    private let aiButton = UIButton(type: .system)
    private let connectAppleMusicButton = UIButton(type: .system)
    private let loadAppleMusicButton = UIButton(type: .system)
    private let createPlaylistButton = UIButton(type: .system)

    private var userPlaylists: [MankiPlaylist] = []
    private var appleMusicPlaylists: [AppleMusicPlaylistSnapshot] = []
    private var songs: [MankiSong] = []
    private var appleMusicSongsByID: [String: Song] = [:]
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
        ThemeManager.styleSecondaryButton(connectAppleMusicButton)
        ThemeManager.styleSecondaryButton(loadAppleMusicButton)
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
        sectionLabel.text = "最近の曲"
        sectionNoteLabel.text = "音から出会った単語を、ここで拾います。"

        aiButton.setTitle("今日のおすすめ", for: .normal)
        connectAppleMusicButton.setTitle("Apple Musicとつなぐ", for: .normal)
        loadAppleMusicButton.setTitle("プレイリストを読み込む", for: .normal)
        createPlaylistButton.setTitle("プレイリスト作成", for: .normal)

        aiButton.addTarget(self, action: #selector(showAIRecommendations), for: .touchUpInside)
        connectAppleMusicButton.addTarget(self, action: #selector(connectAppleMusicTapped), for: .touchUpInside)
        loadAppleMusicButton.addTarget(self, action: #selector(loadAppleMusicPlaylistsTapped), for: .touchUpInside)
        createPlaylistButton.addTarget(self, action: #selector(createPlaylistTapped), for: .touchUpInside)

        let buttonStack = UIStackView(arrangedSubviews: [aiButton, connectAppleMusicButton, loadAppleMusicButton, createPlaylistButton])
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

        let headerContainer = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 260))
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
        appleMusicSongsByID = [:]
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
            self.appleMusicSongsByID = [:]
            self.sourceMode = .localPlaylist(title: playlist.name)
            self.songs = playlist.songs
            self.refreshContent(note: "ローカルのプレイリストを作成しました。MusicKit なしで保存されています。")
        })
        present(alert, animated: true)
    }

    @objc private func showAIRecommendations() {
        Task { [weak self] in
            guard let self else { return }
            sourceMode = .ai
            appleMusicSongsByID = [:]

            guard let recommended = RecommendedSongProvider.shared.todayRecommendation() else {
                songs = []
                refreshContent(note: "今日のおすすめ曲は準備中です。")
                return
            }

            guard !recommended.appleMusicID.isEmpty,
                  LyricsRepository.shared.hasLyrics(for: recommended.lyricsID) else {
                songs = [recommended.mankiSong]
                refreshContent(note: "今日のおすすめ曲は準備中です。")
                return
            }

            if #available(iOS 15.0, *) {
                let appleSong = await service.fetchAppleMusicSongByID(recommended.appleMusicID)
                if let appleSong {
                    let mergedSong = MankiSong(
                        id: recommended.mankiSong.id,
                        title: appleSong.title,
                        artist: appleSong.artistName,
                        appleMusicID: recommended.appleMusicID,
                        albumTitle: appleSong.albumTitle ?? recommended.mankiSong.albumTitle,
                        artworkURL: appleSong.artwork?.url(width: 300, height: 300) ?? recommended.mankiSong.artworkURL,
                        lyricsID: recommended.lyricsID,
                        mood: recommended.mankiSong.mood,
                        level: recommended.mankiSong.level,
                        keywords: recommended.mankiSong.keywords,
                        lyricsLines: recommended.mankiSong.lyricsLines,
                        previewURL: appleSong.previewAssets?.first?.url ?? recommended.mankiSong.previewURL,
                        timedLyrics: recommended.mankiSong.timedLyrics
                    )
                    songs = [mergedSong]
                    appleMusicSongsByID = [mergedSong.id: appleSong]
                    refreshContent(note: recommended.reason)
                } else {
                    songs = [recommended.mankiSong]
                    refreshContent(note: "今日のおすすめ曲は準備中です。")
                }
            } else {
                songs = [recommended.mankiSong]
                refreshContent(note: "今日のおすすめ曲は準備中です。")
            }
        }
    }

    @objc private func connectAppleMusicTapped() {
        Task { [weak self] in
            guard let self else { return }
            guard #available(iOS 15.0, *) else {
                self.presentUnifiedModal(
                    title: "Apple Music",
                    message: "この機能はiOS 15以降で利用できます。",
                    actions: [UnifiedModalAction(title: "OK")]
                )
                return
            }

            let granted = await service.requestAppleMusicPermission()
            if granted {
                self.presentUnifiedModal(
                    title: "Apple Music",
                    message: "Apple Musicに接続しました。プレイリストを読み込めます。",
                    actions: [UnifiedModalAction(title: "OK")]
                )
            } else {
                self.presentUnifiedModal(
                    title: "Apple Music",
                    message: "Apple Musicへのアクセスが許可されていません。設定から許可してください。",
                    actions: [UnifiedModalAction(title: "OK")]
                )
            }
        }
    }

    @objc private func loadAppleMusicPlaylistsTapped() {
        Task { [weak self] in
            guard let self else { return }
            guard #available(iOS 15.0, *) else {
                self.presentUnifiedModal(
                    title: "Apple Music",
                    message: "この機能はiOS 15以降で利用できます。",
                    actions: [UnifiedModalAction(title: "OK")]
                )
                return
            }

            let granted = await service.requestAppleMusicPermission()
            guard granted else {
                self.presentUnifiedModal(
                    title: "Apple Music",
                    message: "Apple Musicへのアクセスが許可されていません。設定から許可してください。",
                    actions: [UnifiedModalAction(title: "OK")]
                )
                return
            }

            let snapshots = await service.fetchDetailedUserPlaylists()
            guard !snapshots.isEmpty else {
                self.presentUnifiedModal(
                    title: "Apple Music",
                    message: "プレイリストを読み込めませんでした。Apple Musicにログインしているか確認してください。",
                    actions: [UnifiedModalAction(title: "OK")]
                )
                return
            }

            self.appleMusicPlaylists = snapshots
            self.tableView.reloadSections(IndexSet(integer: 1), with: .automatic)
            self.refreshContent(note: "Apple Musicプレイリストを読み込みました。上の一覧からプレイリストを選んでください。")
        }
    }

    private func loadLocalPlaylist(_ playlist: MankiPlaylist) {
        sourceMode = .localPlaylist(title: playlist.name)
        appleMusicSongsByID = [:]
        songs = playlist.songs
        refreshContent(note: "作成したプレイリストです。")
    }

    @available(iOS 15.0, *)
    private func loadApplePlaylist(_ snapshot: AppleMusicPlaylistSnapshot) {
        sourceMode = .applePlaylist(title: snapshot.title)
        let mappedSongs = snapshot.songs.map(MankiSong.init(from:))
        appleMusicSongsByID = Dictionary(uniqueKeysWithValues: zip(mappedSongs.map(\.id), snapshot.songs))
        songs = mappedSongs
        refreshContent(note: snapshot.songs.isEmpty ? "このプレイリストには曲がありません。" : "Apple Musicの曲をそのまま開けます。")
    }

    private func openLyrics(for song: MankiSong, startLearning: Bool) {
        MusicLearningStore.saveRecent(song: song)
        let appleMusicSong = appleMusicSongsByID[song.id]
        let controller = LyricsViewController(song: song, appleMusicSong: appleMusicSong, startLearning: startLearning)
        navigationController?.pushViewController(controller, animated: true)
    }

    private func playSongFromList(_ song: MankiSong) {
        print("Play tapped for:", song.id, song.title)

        if #available(iOS 15.0, *), let appleSong = appleMusicSongsByID[song.id] {
            Task { [weak self] in
                guard let self else { return }
                let success = await service.playAppleMusicSong(appleSong, expectedSongID: song.id)
                if !success {
                    self.presentUnifiedModal(
                        title: "再生エラー",
                        message: "この曲を再生できませんでした。Apple Musicの登録状況を確認してください。",
                        actions: [UnifiedModalAction(title: "OK")]
                    )
                }
            }
            return
        }

        if #available(iOS 15.0, *), let appleMusicID = song.appleMusicID {
            Task { [weak self] in
                guard let self else { return }
                let success = await service.playAppleMusicSongByID(appleMusicID, expectedSongID: song.id)
                if !success {
                    self.presentUnifiedModal(
                        title: "再生エラー",
                        message: "この曲を再生できませんでした。Apple Musicの登録状況を確認してください。",
                        actions: [UnifiedModalAction(title: "OK")]
                    )
                }
            }
            return
        }

        if let previewURL = song.previewURL {
            service.playPreview(url: previewURL, songID: song.id)
        } else {
            service.playSong(song)
        }
    }
}

extension MusicViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        3
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return max(userPlaylists.count, 1)
        case 1:
            return max(appleMusicPlaylists.count, 1)
        default:
            return songs.count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            let cell = tableView.dequeueReusableCell(withIdentifier: MusicPlaylistCell.reuseIdentifier) as? MusicPlaylistCell
                ?? MusicPlaylistCell(style: .default, reuseIdentifier: MusicPlaylistCell.reuseIdentifier)
            if userPlaylists.isEmpty {
                cell.configurePlaceholder(title: "まだプレイリストがありません", subtitle: "上のボタンから作成できます")
            } else {
                cell.configure(playlist: userPlaylists[indexPath.row])
            }
            return cell
        case 1:
            let cell = tableView.dequeueReusableCell(withIdentifier: MusicPlaylistCell.reuseIdentifier) as? MusicPlaylistCell
                ?? MusicPlaylistCell(style: .default, reuseIdentifier: MusicPlaylistCell.reuseIdentifier)
            if appleMusicPlaylists.isEmpty {
                cell.configurePlaceholder(title: "Apple Music未接続", subtitle: "上のボタンから接続してプレイリストを読み込めます")
            } else {
                cell.configure(appleMusicPlaylist: appleMusicPlaylists[indexPath.row])
            }
            return cell
        default:
            let cell = tableView.dequeueReusableCell(withIdentifier: MusicSongCell.reuseIdentifier, for: indexPath) as! MusicSongCell
            let song = songs[indexPath.row]
            let isAppleMusicSong = appleMusicSongsByID[song.id] != nil || song.appleMusicID != nil
            cell.configure(song: song, isAppleMusicSong: isAppleMusicSong)
            cell.onLyricsTapped = { [weak self] in
                self?.openLyrics(for: song, startLearning: false)
            }
            cell.onPlayTapped = { [weak self] in
                self?.playSongFromList(song)
            }
            return cell
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return "My Playlists"
        case 1:
            return "Apple Musicプレイリスト"
        default:
            return sourceMode.sectionTitle
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.section {
        case 0:
            guard !userPlaylists.isEmpty else { return }
            loadLocalPlaylist(userPlaylists[indexPath.row])
        case 1:
            guard #available(iOS 15.0, *), !appleMusicPlaylists.isEmpty else { return }
            loadApplePlaylist(appleMusicPlaylists[indexPath.row])
        default:
            guard indexPath.row < songs.count else { return }
            let song = songs[indexPath.row]
            openLyrics(for: song, startLearning: false)
        }
    }
}

private final class MusicPlaylistCell: UITableViewCell {
    static let reuseIdentifier = "MusicPlaylistCell"

    private let cardView = UIView()
    private let artworkView = UIImageView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private var artworkTask: Task<Void, Never>?
    private var artworkURLString: String?

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
        artworkURLString = nil
        artworkView.image = nil
        iconView.isHidden = false
    }

    private func configureUI() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        [cardView, artworkView, iconView, titleLabel, subtitleLabel].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        contentView.addSubview(cardView)
        [artworkView, iconView, titleLabel, subtitleLabel].forEach { cardView.addSubview($0) }

        artworkView.layer.cornerRadius = 12
        artworkView.clipsToBounds = true
        artworkView.contentMode = .scaleAspectFill

        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AppSpacing.s(12)),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -AppSpacing.s(12)),
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: AppSpacing.s(6)),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -AppSpacing.s(6)),

            artworkView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: AppSpacing.s(14)),
            artworkView.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            artworkView.widthAnchor.constraint(equalToConstant: 52),
            artworkView.heightAnchor.constraint(equalToConstant: 52),

            iconView.centerXAnchor.constraint(equalTo: artworkView.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: artworkView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),

            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: AppSpacing.s(12)),
            titleLabel.leadingAnchor.constraint(equalTo: artworkView.trailingAnchor, constant: AppSpacing.s(12)),
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
        artworkView.backgroundColor = palette.surfaceAlt.withAlphaComponent(0.92)
        artworkView.layer.borderWidth = 2
        artworkView.layer.borderColor = palette.border.cgColor
        iconView.image = UIImage(systemName: "music.note.list")?.withTintColor(palette.text, renderingMode: .alwaysOriginal)
        titleLabel.applyMankiTextStyle(.sectionTitle, color: palette.text, numberOfLines: 1)
        subtitleLabel.applyMankiTextStyle(.caption, color: palette.mutedText, numberOfLines: 1)
        titleLabel.text = playlist.name
        subtitleLabel.text = "\(playlist.type.displayName) / \(playlist.songs.count) songs"
    }

    @available(iOS 15.0, *)
    func configure(appleMusicPlaylist snapshot: AppleMusicPlaylistSnapshot) {
        let palette = ThemeManager.palette()
        ThemeManager.styleCard(cardView, fillColor: palette.surface.withAlphaComponent(0.95))
        artworkView.backgroundColor = palette.surfaceAlt.withAlphaComponent(0.92)
        artworkView.layer.borderWidth = 2
        artworkView.layer.borderColor = palette.border.cgColor
        iconView.image = UIImage(systemName: "music.note.list")?.withTintColor(palette.text, renderingMode: .alwaysOriginal)
        titleLabel.applyMankiTextStyle(.sectionTitle, color: palette.text, numberOfLines: 2)
        subtitleLabel.applyMankiTextStyle(.caption, color: palette.mutedText, numberOfLines: 1)
        titleLabel.text = snapshot.title
        subtitleLabel.text = "APPLE / \(snapshot.songCount) songs"
        loadArtwork(from: snapshot.artworkURL)
    }

    func configurePlaceholder(title: String, subtitle: String) {
        let palette = ThemeManager.palette()
        ThemeManager.styleCard(cardView, fillColor: palette.surface.withAlphaComponent(0.95))
        artworkView.backgroundColor = palette.surfaceAlt.withAlphaComponent(0.92)
        artworkView.layer.borderWidth = 2
        artworkView.layer.borderColor = palette.border.cgColor
        iconView.image = UIImage(systemName: "music.note")?.withTintColor(palette.mutedText, renderingMode: .alwaysOriginal)
        titleLabel.applyMankiTextStyle(.sectionTitle, color: palette.mutedText, numberOfLines: 1)
        subtitleLabel.applyMankiTextStyle(.caption, color: palette.mutedText, numberOfLines: 1)
        titleLabel.text = title
        subtitleLabel.text = subtitle
    }

    private func loadArtwork(from url: URL?) {
        artworkTask?.cancel()
        artworkView.image = nil
        iconView.isHidden = false
        guard let url else { return }
        artworkURLString = url.absoluteString
        artworkTask = Task { [weak self] in
            guard let self else { return }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard !Task.isCancelled, let image = UIImage(data: data), self.artworkURLString == url.absoluteString else { return }
                await MainActor.run {
                    self.artworkView.image = image
                    self.iconView.isHidden = true
                }
            } catch {
                return
            }
        }
    }
}

private final class MusicSongCell: UITableViewCell {
    static let reuseIdentifier = "MusicSongCell"

    private let cardView = UIView()
    private let artworkView = UIImageView()
    private let iconLabel = UILabel()
    private let moodLabel = UILabel()
    private let titleLabel = UILabel()
    private let artistLabel = UILabel()
    private let metaLabel = UILabel()
    private let lyricsButton = UIButton(type: .system)
    private let playButton = UIButton(type: .system)

    private var artworkTask: Task<Void, Never>?
    private var artworkURLString: String?

    var onLyricsTapped: (() -> Void)?
    var onPlayTapped: (() -> Void)?

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
        artworkURLString = nil
        artworkView.image = nil
        iconLabel.isHidden = false
        moodLabel.isHidden = false
        onLyricsTapped = nil
        onPlayTapped = nil
    }

    private func configureUI() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        [cardView, artworkView, iconLabel, moodLabel, titleLabel, artistLabel, metaLabel, lyricsButton, playButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        artworkView.layer.cornerRadius = 18
        artworkView.layer.borderWidth = 2
        artworkView.clipsToBounds = true
        artworkView.contentMode = .scaleAspectFill

        iconLabel.text = "♫"
        iconLabel.textAlignment = .center
        moodLabel.textAlignment = .center

        lyricsButton.setTitle("歌詞を見る", for: .normal)
        playButton.setTitle("再生", for: .normal)
        lyricsButton.addTarget(self, action: #selector(tapLyrics), for: .touchUpInside)
        playButton.addTarget(self, action: #selector(tapPlay), for: .touchUpInside)

        let buttonStack = UIStackView(arrangedSubviews: [lyricsButton, playButton])
        buttonStack.axis = .horizontal
        buttonStack.spacing = AppSpacing.s(10)
        buttonStack.distribution = .fillEqually
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(cardView)
        [artworkView, titleLabel, artistLabel, metaLabel, buttonStack].forEach { cardView.addSubview($0) }
        artworkView.addSubview(iconLabel)
        artworkView.addSubview(moodLabel)

        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AppSpacing.s(12)),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -AppSpacing.s(12)),
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: AppSpacing.s(8)),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -AppSpacing.s(8)),

            artworkView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: AppSpacing.s(14)),
            artworkView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: AppSpacing.s(14)),
            artworkView.widthAnchor.constraint(equalToConstant: 78),
            artworkView.heightAnchor.constraint(equalToConstant: 78),

            iconLabel.centerXAnchor.constraint(equalTo: artworkView.centerXAnchor),
            iconLabel.topAnchor.constraint(equalTo: artworkView.topAnchor, constant: AppSpacing.s(10)),

            moodLabel.leadingAnchor.constraint(equalTo: artworkView.leadingAnchor, constant: AppSpacing.s(8)),
            moodLabel.trailingAnchor.constraint(equalTo: artworkView.trailingAnchor, constant: -AppSpacing.s(8)),
            moodLabel.bottomAnchor.constraint(equalTo: artworkView.bottomAnchor, constant: -AppSpacing.s(10)),

            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: AppSpacing.s(16)),
            titleLabel.leadingAnchor.constraint(equalTo: artworkView.trailingAnchor, constant: AppSpacing.s(12)),
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -AppSpacing.s(14)),

            artistLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: AppSpacing.s(6)),
            artistLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            artistLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            metaLabel.topAnchor.constraint(equalTo: artistLabel.bottomAnchor, constant: AppSpacing.s(6)),
            metaLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            metaLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            buttonStack.topAnchor.constraint(equalTo: artworkView.bottomAnchor, constant: AppSpacing.s(12)),
            buttonStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: AppSpacing.s(14)),
            buttonStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -AppSpacing.s(14)),
            buttonStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -AppSpacing.s(14))
        ])
    }

    func configure(song: MankiSong, isAppleMusicSong: Bool) {
        let palette = ThemeManager.palette()
        ThemeManager.styleCard(cardView, fillColor: palette.surface.withAlphaComponent(0.95))
        artworkView.backgroundColor = palette.surfaceAlt.withAlphaComponent(0.92)
        artworkView.layer.borderColor = palette.border.cgColor
        iconLabel.font = AppFont.jp(size: 24, weight: .bold)
        iconLabel.textColor = palette.text
        moodLabel.font = AppFont.jp(size: 11, weight: .bold)
        moodLabel.textColor = palette.mutedText
        moodLabel.text = isAppleMusicSong ? "APPLE" : song.mood.uppercased()
        titleLabel.applyMankiTextStyle(.sectionTitle, color: palette.text, numberOfLines: 2)
        artistLabel.applyMankiTextStyle(.body, color: palette.mutedText, numberOfLines: 1)
        metaLabel.applyMankiTextStyle(.caption, color: palette.mutedText, numberOfLines: 2)
        titleLabel.text = song.title
        artistLabel.text = song.artist
        if let albumTitle = song.albumTitle, !albumTitle.isEmpty {
            metaLabel.text = albumTitle
        } else if isAppleMusicSong {
            metaLabel.text = "Apple Music"
        } else {
            metaLabel.text = "\(song.level.uppercased()) / \(song.keywords.count) words"
        }
        ThemeManager.styleSecondaryButton(lyricsButton)
        ThemeManager.stylePrimaryButton(playButton)
        loadArtwork(from: song.artworkURL)
    }

    private func loadArtwork(from url: URL?) {
        artworkTask?.cancel()
        artworkView.image = nil
        iconLabel.isHidden = false
        guard let url else { return }
        artworkURLString = url.absoluteString
        artworkTask = Task { [weak self] in
            guard let self else { return }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard !Task.isCancelled, let image = UIImage(data: data), self.artworkURLString == url.absoluteString else { return }
                await MainActor.run {
                    self.artworkView.image = image
                    self.iconLabel.isHidden = true
                }
            } catch {
                return
            }
        }
    }

    @objc private func tapLyrics() {
        onLyricsTapped?()
    }

    @objc private func tapPlay() {
        onPlayTapped?()
    }
}
