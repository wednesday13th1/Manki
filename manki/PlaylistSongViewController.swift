import UIKit

final class PlaylistSongViewController: BaseViewController {
    private let playlistID: String
    private let songID: String
    private let emotionFilter: EmotionTag?
    private let difficultyFilter: PlaylistCardDifficulty?

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let titleLabel = UILabel()
    private let artistLabel = UILabel()
    private let metaLabel = UILabel()
    private let reviewButton = UIButton(type: .system)
    private let emptyLabel = UILabel()

    private var playlist: Playlist?
    private var song: PlaylistSong?

    init(playlistID: String,
         songID: String,
         emotionFilter: EmotionTag?,
         difficultyFilter: PlaylistCardDifficulty?) {
        self.playlistID = playlistID
        self.songID = songID
        self.emotionFilter = emotionFilter
        self.difficultyFilter = difficultyFilter
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "曲カード"
        configureUI()
        reloadSong()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadSong()
        tableView.reloadData()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateHeaderLayout()
    }

    override func applyBaseTheme() {
        super.applyBaseTheme()
        let palette = ThemeManager.palette()
        titleLabel.textColor = palette.text
        artistLabel.textColor = palette.mutedText
        metaLabel.textColor = palette.mutedText
        emptyLabel.textColor = palette.mutedText
        ThemeManager.stylePrimaryButton(reviewButton)
    }

    private func configureUI() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "カード追加",
            style: .plain,
            target: self,
            action: #selector(addCard)
        )

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(PlaylistCardCell.self, forCellReuseIdentifier: PlaylistCardCell.reuseIdentifier)
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 160
        tableView.backgroundColor = .clear

        titleLabel.numberOfLines = 0
        artistLabel.numberOfLines = 0
        metaLabel.numberOfLines = 0
        emptyLabel.numberOfLines = 0
        emptyLabel.textAlignment = .center
        emptyLabel.text = "この曲に一致するカードがありません。"

        reviewButton.setTitle("この曲を復習", for: .normal)
        reviewButton.addTarget(self, action: #selector(startReview), for: .touchUpInside)

        let headerStack = UIStackView(arrangedSubviews: [titleLabel, artistLabel, metaLabel, reviewButton])
        headerStack.axis = .vertical
        headerStack.spacing = AppSpacing.s(12)
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 180))
        headerView.addSubview(headerStack)
        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: headerView.topAnchor, constant: AppSpacing.s(16)),
            headerStack.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: AppSpacing.s(16)),
            headerStack.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -AppSpacing.s(16)),
            headerStack.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -AppSpacing.s(12))
        ])
        tableView.tableHeaderView = headerView

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
    }

    private func reloadSong() {
        playlist = PlaylistStore.loadPlaylists().first(where: { $0.id == playlistID })
        song = playlist?.songs.first(where: { $0.id == songID })
        titleLabel.applyMankiTextStyle(.screenTitle, color: ThemeManager.palette().text, numberOfLines: 0)
        artistLabel.applyMankiTextStyle(.body, color: ThemeManager.palette().mutedText, numberOfLines: 0)
        metaLabel.applyMankiTextStyle(.caption, color: ThemeManager.palette().mutedText, numberOfLines: 0)
        titleLabel.text = song?.title
        artistLabel.text = [
            song?.artist,
            song?.albumTitle
        ].compactMap { value in
            guard let value, !value.isEmpty else { return nil }
            return value
        }.joined(separator: " / ")
        metaLabel.text = [
            "\(cards.count)カード",
            song?.source == .appleMusic ? "APPLE MUSIC" : "MANUAL"
        ].joined(separator: " / ")
        updateHeaderLayout()
        emptyLabel.isHidden = !cards.isEmpty
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

    private var cards: [PlaylistCard] {
        song?.filteredCards(emotion: emotionFilter, difficulty: difficultyFilter) ?? []
    }

    @objc private func addCard() {
        guard let song else { return }
        let controller = PlaylistEditorViewController(sourceSongTitle: song.title) { [weak self] card in
            guard let self else { return }
            var playlists = PlaylistStore.loadPlaylists()
            guard let playlistIndex = playlists.firstIndex(where: { $0.id == self.playlistID }),
                  let songIndex = playlists[playlistIndex].songs.firstIndex(where: { $0.id == self.songID }) else { return }
            playlists[playlistIndex].songs[songIndex].cards.append(card)
            PlaylistStore.savePlaylists(playlists)
            self.reloadSong()
            self.tableView.reloadData()
        }
        navigationController?.pushViewController(controller, animated: true)
    }

    @objc private func startReview() {
        let words = cards.map { $0.asSavedWord() }
        guard !words.isEmpty else {
            presentUnifiedModal(title: "復習対象なし", message: "カードを追加してから復習してください。", actions: [UnifiedModalAction(title: "OK")])
            return
        }
        presentUnifiedModal(
            title: "この曲を復習",
            message: nil,
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
}

extension PlaylistSongViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        cards.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: PlaylistCardCell.reuseIdentifier, for: indexPath) as! PlaylistCardCell
        cell.configure(card: cards[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        true
    }

    func tableView(_ tableView: UITableView,
                   commit editingStyle: UITableViewCell.EditingStyle,
                   forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }
        let cardID = cards[indexPath.row].id
        var playlists = PlaylistStore.loadPlaylists()
        guard let playlistIndex = playlists.firstIndex(where: { $0.id == playlistID }),
              let songIndex = playlists[playlistIndex].songs.firstIndex(where: { $0.id == songID }) else { return }
        playlists[playlistIndex].songs[songIndex].cards.removeAll { $0.id == cardID }
        PlaylistStore.savePlaylists(playlists)
        reloadSong()
        tableView.reloadData()
    }
}
