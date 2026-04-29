import UIKit
import MusicKit

struct AppleMusicSongResult {
    let id: String
    let title: String
    let artistName: String
    let albumTitle: String?
    let artworkURL: URL?
    let previewURL: URL?
    let duration: TimeInterval?

    init(song: Song) {
        id = song.id.rawValue
        title = song.title
        artistName = song.artistName
        albumTitle = song.albumTitle
        artworkURL = song.artwork?.url(width: 160, height: 160)
        previewURL = song.previewAssets?.first?.url
        duration = song.duration
    }

    var formattedDuration: String? {
        guard let duration else { return nil }
        let totalSeconds = Int(duration.rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    func asPlaylistSong() -> PlaylistSong {
        PlaylistSong(
            title: title,
            artist: artistName,
            appleMusicId: id,
            albumTitle: albumTitle,
            artworkUrl: artworkURL?.absoluteString,
            previewUrl: previewURL?.absoluteString,
            duration: duration,
            source: .appleMusic,
            cards: []
        )
    }
}

struct AppleMusicAccessState {
    let isAuthorized: Bool
    let message: String?
}

enum AppleMusicCatalogService {
    static func requestAccess() async -> AppleMusicAccessState {
        let status = await MusicAuthorization.request()
        guard status == .authorized else {
            return AppleMusicAccessState(
                isAuthorized: false,
                message: "Apple Music の利用許可がないため、曲検索を開けません。設定アプリで許可してください。"
            )
        }

        do {
            let subscription = try await MusicSubscription.current
            if subscription.canPlayCatalogContent {
                return AppleMusicAccessState(
                    isAuthorized: true,
                    message: "Apple Music カタログにアクセスできます。歌詞全文は保存せず、曲情報と短いプレビューURLのみ扱います。"
                )
            }
            return AppleMusicAccessState(
                isAuthorized: true,
                message: "検索と曲情報の追加はできます。再生やライブラリ操作には Apple Music の契約状態が影響する場合があります。"
            )
        } catch {
            return AppleMusicAccessState(
                isAuthorized: true,
                message: "権限は確認できました。契約状態を取得できなかったため、検索のみ先に利用します。"
            )
        }
    }

    static func searchSongs(term: String) async throws -> [AppleMusicSongResult] {
        var request = MusicCatalogSearchRequest(term: term, types: [Song.self])
        request.limit = 20
        let response = try await request.response()
        return response.songs.map(AppleMusicSongResult.init(song:))
    }
}

final class AppleMusicSearchViewController: BaseViewController {
    private let statusMessage: String?
    private let existingAppleMusicIDs: Set<String>
    private let onSelectSong: (PlaylistSong) -> Void

    private let searchBar = UISearchBar()
    private let statusLabel = UILabel()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyLabel = UILabel()
    private var searchTask: Task<Void, Never>?
    private var results: [AppleMusicSongResult] = []

    init(statusMessage: String?, existingAppleMusicIDs: Set<String>, onSelectSong: @escaping (PlaylistSong) -> Void) {
        self.statusMessage = statusMessage
        self.existingAppleMusicIDs = existingAppleMusicIDs
        self.onSelectSong = onSelectSong
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        searchTask?.cancel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Apple Music検索"
        configureUI()
        applyContent()
    }

    override func applyBaseTheme() {
        super.applyBaseTheme()
        let palette = ThemeManager.palette()
        ThemeManager.applySearchBar(searchBar)
        statusLabel.applyMankiTextStyle(.caption, color: palette.mutedText, numberOfLines: 0)
        emptyLabel.applyMankiTextStyle(.body, color: palette.mutedText, alignment: .center, numberOfLines: 0)
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
    }

    private func configureUI() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "閉じる",
            style: .plain,
            target: self,
            action: #selector(closeModal)
        )

        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.placeholder = "曲名・アーティスト名で検索"
        searchBar.delegate = self

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.numberOfLines = 0

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(AppleMusicSearchResultCell.self, forCellReuseIdentifier: AppleMusicSearchResultCell.reuseIdentifier)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 132

        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.text = "曲名またはアーティスト名を入力して検索してください。"
        emptyLabel.textAlignment = .center

        view.addSubview(searchBar)
        view.addSubview(statusLabel)
        view.addSubview(tableView)
        view.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: AppSpacing.s(10)),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AppSpacing.s(12)),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AppSpacing.s(12)),

            statusLabel.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: AppSpacing.s(10)),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AppSpacing.s(16)),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AppSpacing.s(16)),

            tableView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: AppSpacing.s(8)),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: tableView.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: AppSpacing.s(24)),
            emptyLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -AppSpacing.s(24))
        ])
    }

    private func applyContent() {
        statusLabel.text = statusMessage ?? "Apple Music カタログ検索を使って曲を Playlist に追加できます。"
        updateEmptyState()
    }

    private func updateEmptyState(message: String? = nil) {
        if let message {
            emptyLabel.text = message
        }
        emptyLabel.isHidden = !results.isEmpty
    }

    private func beginSearch(with query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            results = []
            tableView.reloadData()
            updateEmptyState(message: "曲名またはアーティスト名を入力して検索してください。")
            return
        }

        searchTask?.cancel()
        updateEmptyState(message: "Apple Music を検索中...")

        searchTask = Task { [weak self] in
            do {
                let items = try await AppleMusicCatalogService.searchSongs(term: trimmedQuery)
                await MainActor.run {
                    guard let self else { return }
                    self.results = items
                    self.tableView.reloadData()
                    self.updateEmptyState(message: items.isEmpty ? "一致する曲が見つかりませんでした。" : nil)
                }
            } catch {
                await MainActor.run {
                    guard let self else { return }
                    self.results = []
                    self.tableView.reloadData()
                    self.updateEmptyState(message: "検索に失敗しました。通信状態と MusicKit 設定を確認してください。")
                }
            }
        }
    }

    @objc private func closeModal() {
        dismiss(animated: true)
    }
}

extension AppleMusicSearchViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        beginSearch(with: searchBar.text ?? "")
    }
}

extension AppleMusicSearchViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        results.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: AppleMusicSearchResultCell.reuseIdentifier, for: indexPath) as! AppleMusicSearchResultCell
        let result = results[indexPath.row]
        let alreadyAdded = existingAppleMusicIDs.contains(result.id)
        cell.configure(result: result, alreadyAdded: alreadyAdded)
        cell.onAddTapped = { [weak self] in
            guard let self else { return }
            guard !alreadyAdded else { return }
            self.onSelectSong(result.asPlaylistSong())
            self.dismiss(animated: true)
        }
        return cell
    }
}
