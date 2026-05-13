//
//  SetViewController.swift
//  manki
//
//  Created by 井上　希稟 on 2026/01/23.
//

import UIKit

private func needsWordIDMigration(from data: Data) -> Bool {
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
        return false
    }
    return json.contains { $0["id"] == nil }
}

final class SetViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UIGestureRecognizerDelegate {

    private let savedWordsFileName = "saved_words.json"
    private enum SetSortOption {
        case created
        case nameAsc
        case nameDesc
        case countAsc
        case countDesc
    }
    private let folderID: String?
    private let showsAll: Bool
    private var sets: [SavedSet] = []
    private var wordsByID: [String: SavedWord] = [:]
    private var setWordCountByID: [String: Int] = [:]
    private var filteredSets: [SavedSet] = []
    private var displayedSetCache: [SavedSet] = []
    private var selectedSets: [SavedSet] = []
    private var sortOption: SetSortOption = .created
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let tapGesture = UITapGestureRecognizer()
    private let emptyLabel = UILabel()
    private let searchController = UISearchController(searchResultsController: nil)
    private let searchContainer = UIView()
    private var searchText: String = ""
    private let themeHeader = UIView()
    private let themeTitleLabel = UILabel()
    private let themeStack = UIStackView()
    private let selectedSetsPanel = UIView()
    private let selectedSetsTitleLabel = UILabel()
    private let selectedSetsEmptyLabel = UILabel()
    private let selectedSetsStack = UIStackView()
    private var themeButtons: [UIButton] = []
    private var themeObserver: NSObjectProtocol?
    private let themeHeaderHeight: CGFloat = 120
    private let retroShellView = UIView()
    private let retroScreenView = UIView()
    private let retroKeypadView = UIView()
    private let retroKeypadGrid = UIStackView()
    private let retroKeypadRowTop = UIStackView()
    private let retroKeypadRowBottom = UIStackView()
    private var retroKeyButtons: [UIButton] = []
    private let retroFolderButton = UIButton(type: .system)
    private let retroWordButton = UIButton(type: .system)
    private let retroSortButton = UIButton(type: .system)
    private let retroAddButton = UIButton(type: .system)
    private let retroAntennaView = UIView()
    private let retroAntennaTipView = UIView()
    private let retroSpeakerView = UIView()
    private let retroClickWheelView = UIView()
    private let retroClickWheelCenterView = UIView()
    private let retroClickWheelVerticalDivider = UIView()
    private let retroClickWheelHorizontalDivider = UIView()
    private let retroClickWheelFolderButton = UIButton(type: .system)
    private let retroClickWheelWordButton = UIButton(type: .system)
    private let retroBadgeLabel = UILabel()
    private let headerContainer = UIView()
    private let keyboardDismissTap = UITapGestureRecognizer()
    private var retroShellBottomConstraint: NSLayoutConstraint?
    private var keypadTopConstraint: NSLayoutConstraint?
    private var clickWheelTopConstraint: NSLayoutConstraint?
    private var clickWheelBottomConstraint: NSLayoutConstraint?
    private var screenBottomConstraint: NSLayoutConstraint?
    private var keyboardObservers: [NSObjectProtocol] = []
    private let hideToggleButton = UIButton(type: .system)
    private var renameGesture: UILongPressGestureRecognizer?
    private var isHandlingSelection = false
    private var reloadTaskID: Int = 0
    private var wordMenuOverlay: UIControl?
    private var wordMenuContainer: UIView?
    private var wordMenuTitleLabel: UILabel?
    private var wordMenuButtons: [UIButton] = []

    private enum RetroNavTag {
        static let icon = 4101
        static let label = 4102
    }

    init(folderID: String?, showsAll: Bool = false) {
        self.folderID = folderID
        self.showsAll = showsAll
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        folderID = nil
        showsAll = true
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = showsAll ? "セット" : (folderID == nil ? "未分類" : "セット")
        view.backgroundColor = .systemBackground
        configureKeyboardDismiss()
        configureKeyboardObservers()
        configureRetroShell()
        configureTableView()
        configureEmptyLabel()
        configureSearch()
        configureThemeHeader()
        applyTheme()
        themeObserver = NotificationCenter.default.addObserver(
            forName: ThemeManager.didChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyTheme()
        }
        let addButton = UIBarButtonItem(title: "追加",
                                        style: .plain,
                                        target: self,
                                        action: #selector(openAddSet))
        let sortButton = UIBarButtonItem(title: "並び替え",
                                         style: .plain,
                                         target: self,
                                         action: #selector(openSortMenu))
        navigationItem.rightBarButtonItems = [addButton, sortButton]
        let wordsButton = UIBarButtonItem(title: "単語",
                                          style: .plain,
                                          target: self,
                                          action: #selector(openWordList))
        let foldersButton = UIBarButtonItem(title: "フォルダー",
                                            style: .plain,
                                            target: self,
                                            action: #selector(openFolderView))
        navigationItem.leftBarButtonItems = [foldersButton, wordsButton]
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
        applyTheme()
        reloadData()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        let nextController = transitionCoordinator?.viewController(forKey: .to)
        if nextController is FolderViewController || nextController is SetViewController {
            navigationController?.setNavigationBarHidden(true, animated: false)
        } else {
            navigationController?.setNavigationBarHidden(false, animated: false)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsSelection = true
        tableView.allowsSelectionDuringEditing = true
    }

    func prepareForInitialTransition(in _: CGRect) {
        loadViewIfNeeded()
        applyTheme()
        reloadData()
        view.setNeedsLayout()
        view.layoutIfNeeded()
        retroShellView.layoutIfNeeded()
        retroKeypadView.layoutIfNeeded()
        retroClickWheelView.layoutIfNeeded()
        tableView.layoutIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateHeaderLayout()
        updateAntennaShape()
        updateClickWheelShape()
    }

    private func updateAntennaShape() {
        let bounds = retroAntennaView.bounds
        guard bounds.width > 0, bounds.height > 0 else { return }
        let radius = bounds.width / 2
        let path = UIBezierPath(roundedRect: bounds, cornerRadius: radius)

        let mask = CAShapeLayer()
        mask.path = path.cgPath
        retroAntennaView.layer.mask = mask
    }

    private func updateClickWheelShape() {
        let wheelBounds = retroClickWheelView.bounds
        if wheelBounds.width > 0 {
            retroClickWheelView.layer.cornerRadius = wheelBounds.width / 2
        }
        let centerBounds = retroClickWheelCenterView.bounds
        if centerBounds.width > 0 {
            retroClickWheelCenterView.layer.cornerRadius = centerBounds.width / 2
        }
    }

    private func configureTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 72
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.delaysContentTouches = false
        tableView.keyboardDismissMode = .onDrag
        retroScreenView.addSubview(searchContainer)
        retroScreenView.addSubview(tableView)

        searchContainer.translatesAutoresizingMaskIntoConstraints = false
        searchController.searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchContainer.addSubview(searchController.searchBar)
        let gesture = UILongPressGestureRecognizer(target: self, action: #selector(handleSetRenameLongPress(_:)))
        gesture.cancelsTouchesInView = false
        gesture.delaysTouchesBegan = false
        gesture.delegate = self
        tableView.addGestureRecognizer(gesture)
        renameGesture = gesture
        tapGesture.addTarget(self, action: #selector(handleTableTap(_:)))
        tapGesture.cancelsTouchesInView = false
        tapGesture.delaysTouchesBegan = false
        tapGesture.delegate = self
        tapGesture.require(toFail: tableView.panGestureRecognizer)
        tableView.addGestureRecognizer(tapGesture)

        NSLayoutConstraint.activate([
            searchContainer.topAnchor.constraint(equalTo: retroScreenView.topAnchor, constant: AppSpacing.s(12)),
            searchContainer.leadingAnchor.constraint(equalTo: retroScreenView.leadingAnchor, constant: AppSpacing.s(12)),
            searchContainer.trailingAnchor.constraint(equalTo: retroScreenView.trailingAnchor, constant: -AppSpacing.s(12)),

            searchController.searchBar.topAnchor.constraint(equalTo: searchContainer.topAnchor, constant: AppSpacing.s(6)),
            searchController.searchBar.leadingAnchor.constraint(equalTo: searchContainer.leadingAnchor, constant: AppSpacing.s(6)),
            searchController.searchBar.trailingAnchor.constraint(equalTo: searchContainer.trailingAnchor, constant: -AppSpacing.s(6)),
            searchController.searchBar.bottomAnchor.constraint(equalTo: searchContainer.bottomAnchor, constant: -AppSpacing.s(6)),

            tableView.topAnchor.constraint(equalTo: searchContainer.bottomAnchor, constant: AppSpacing.s(8)),
            tableView.leadingAnchor.constraint(equalTo: retroScreenView.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: retroScreenView.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: retroScreenView.bottomAnchor),
        ])

        retroScreenView.bringSubviewToFront(searchContainer)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    @objc private func handleTableTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended else { return }
        let location = gesture.location(in: tableView)
        guard tableView.indexPathForRow(at: location) != nil else {
            view.endEditing(true)
            return
        }
        view.endEditing(true)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    private func handleSelection(at indexPath: IndexPath) {
        guard !isHandlingSelection else { return }
        guard indexPath.row < displayedSetCache.count else { return }
        isHandlingSelection = true
        let set = displayedSetCache[indexPath.row]
        toggleSetSelection(set, at: indexPath)
        DispatchQueue.main.async { [weak self] in
            self?.isHandlingSelection = false
        }
    }

    private func toggleSetSelection(_ set: SavedSet, at indexPath: IndexPath) {
        if let selectedIndex = selectedSets.firstIndex(where: { $0.id == set.id }) {
            selectedSets.remove(at: selectedIndex)
            updateSelectedSetsPanel(animated: true, insertedSetID: nil)
        } else {
            selectedSets.append(set)
            updateSelectedSetsPanel(animated: true, insertedSetID: set.id)
        }
        tableView.reloadRows(at: [indexPath], with: .fade)
    }

    @objc private func removeSelectedSet(_ sender: UIButton) {
        guard sender.tag >= 0, sender.tag < selectedSets.count else { return }
        let removedID = selectedSets[sender.tag].id
        selectedSets.remove(at: sender.tag)
        updateSelectedSetsPanel(animated: true, insertedSetID: nil)
        if let row = displayedSetCache.firstIndex(where: { $0.id == removedID }) {
            tableView.reloadRows(at: [IndexPath(row: row, section: 0)], with: .fade)
        }
    }

    @objc private func openSelectedSet(_ sender: UIButton) {
        guard sender.tag >= 0, sender.tag < selectedSets.count else { return }
        openSetDetail(selectedSets[sender.tag])
    }

    private func openSetDetail(_ set: SavedSet) {
        let controller = SetDetailViewController(setID: set.id)
        if let nav = navigationController {
            nav.pushViewController(controller, animated: true)
        } else {
            let nav = UINavigationController(rootViewController: controller)
            nav.modalPresentationStyle = .fullScreen
            present(nav, animated: true)
        }
    }

    private func configureEmptyLabel() {
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.text = "セットがありません。\n右上の「追加」で作成できます。"
        emptyLabel.textAlignment = .center
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.numberOfLines = 0
        retroScreenView.addSubview(emptyLabel)
        retroScreenView.bringSubviewToFront(emptyLabel)
        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: retroScreenView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: retroScreenView.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(greaterThanOrEqualTo: retroScreenView.leadingAnchor, constant: AppSpacing.s(20)),
            emptyLabel.trailingAnchor.constraint(lessThanOrEqualTo: retroScreenView.trailingAnchor, constant: -AppSpacing.s(20)),
        ])
    }

    private func configureSearch() {
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.hidesNavigationBarDuringPresentation = false
        searchController.searchResultsUpdater = self
        searchController.searchBar.placeholder = "セット名で検索"
        searchController.searchBar.sizeToFit()
        definesPresentationContext = true
    }

    private func configureKeyboardDismiss() {
        keyboardDismissTap.addTarget(self, action: #selector(dismissKeyboard))
        keyboardDismissTap.cancelsTouchesInView = false
        keyboardDismissTap.delegate = self
        view.addGestureRecognizer(keyboardDismissTap)
    }

    private func configureKeyboardObservers() {
        let center = NotificationCenter.default
        let show = center.addObserver(forName: UIResponder.keyboardWillShowNotification,
                                      object: nil,
                                      queue: .main) { [weak self] _ in
            self?.setKeyboardCompactLayout(true)
        }
        let hide = center.addObserver(forName: UIResponder.keyboardWillHideNotification,
                                      object: nil,
                                      queue: .main) { [weak self] _ in
            self?.setKeyboardCompactLayout(false)
        }
        keyboardObservers = [show, hide]
    }

    private func setKeyboardCompactLayout(_ compact: Bool) {
        if compact {
            retroKeypadView.isHidden = true
            retroClickWheelView.isHidden = true
            if let keypadTopConstraint {
                NSLayoutConstraint.deactivate([keypadTopConstraint])
            }
            if let clickWheelTopConstraint {
                NSLayoutConstraint.deactivate([clickWheelTopConstraint])
            }
            if let clickWheelBottomConstraint {
                NSLayoutConstraint.deactivate([clickWheelBottomConstraint])
            }
            if let screenBottomConstraint {
                NSLayoutConstraint.activate([screenBottomConstraint])
            }
        } else {
            retroKeypadView.isHidden = false
            retroClickWheelView.isHidden = false
            if let screenBottomConstraint {
                NSLayoutConstraint.deactivate([screenBottomConstraint])
            }
            if let keypadTopConstraint {
                NSLayoutConstraint.activate([keypadTopConstraint])
            }
            if let clickWheelTopConstraint {
                NSLayoutConstraint.activate([clickWheelTopConstraint])
            }
            if let clickWheelBottomConstraint {
                NSLayoutConstraint.activate([clickWheelBottomConstraint])
            }
        }
        view.layoutIfNeeded()
    }

    private func configureRetroShell() {
        retroShellView.translatesAutoresizingMaskIntoConstraints = false
        retroScreenView.translatesAutoresizingMaskIntoConstraints = false
        retroKeypadView.translatesAutoresizingMaskIntoConstraints = false
        retroSpeakerView.translatesAutoresizingMaskIntoConstraints = false
        retroBadgeLabel.translatesAutoresizingMaskIntoConstraints = false
        retroKeypadGrid.translatesAutoresizingMaskIntoConstraints = false
        retroKeypadRowTop.translatesAutoresizingMaskIntoConstraints = false
        retroKeypadRowBottom.translatesAutoresizingMaskIntoConstraints = false
        retroAntennaView.translatesAutoresizingMaskIntoConstraints = false
        retroAntennaTipView.translatesAutoresizingMaskIntoConstraints = false
        retroClickWheelView.translatesAutoresizingMaskIntoConstraints = false
        retroClickWheelCenterView.translatesAutoresizingMaskIntoConstraints = false
        retroClickWheelVerticalDivider.translatesAutoresizingMaskIntoConstraints = false
        retroClickWheelHorizontalDivider.translatesAutoresizingMaskIntoConstraints = false
        retroClickWheelFolderButton.translatesAutoresizingMaskIntoConstraints = false
        retroClickWheelWordButton.translatesAutoresizingMaskIntoConstraints = false

        retroKeypadGrid.axis = .vertical
        retroKeypadGrid.spacing = AppSpacing.s(10)
        retroKeypadGrid.distribution = .fillEqually

        retroKeypadRowTop.axis = .horizontal
        retroKeypadRowTop.spacing = AppSpacing.s(12)
        retroKeypadRowTop.distribution = .fill

        retroKeypadRowBottom.axis = .horizontal
        retroKeypadRowBottom.spacing = AppSpacing.s(12)
        retroKeypadRowBottom.distribution = .fillEqually

        retroKeyButtons = [retroFolderButton, retroWordButton, retroSortButton, retroAddButton]
        let configButtons: [(UIButton, String, String)] = [
            (retroFolderButton, "セット", "folder.fill"),
            (retroWordButton, "共有", "square.and.arrow.up"),
            (retroSortButton, "並替", "arrow.up.arrow.down"),
            (retroAddButton, "学習", "checkmark.circle.fill")
        ]
        configButtons.forEach { button, title, symbolName in
            configureRetroNavButton(button, title: title, symbolName: symbolName)
        }
        retroFolderButton.setContentHuggingPriority(.defaultLow, for: .horizontal)
        retroWordButton.setContentHuggingPriority(.required, for: .horizontal)

        retroKeypadRowTop.addArrangedSubview(retroAddButton)
        retroKeypadRowTop.addArrangedSubview(retroWordButton)
        retroKeypadRowBottom.addArrangedSubview(retroSortButton)
        retroKeypadRowBottom.addArrangedSubview(retroFolderButton)
        retroKeypadGrid.addArrangedSubview(retroKeypadRowTop)
        retroKeypadGrid.addArrangedSubview(retroKeypadRowBottom)

        retroBadgeLabel.text = "Y2K"
        retroBadgeLabel.textAlignment = .center

        [retroClickWheelFolderButton, retroClickWheelWordButton].forEach { button in
            button.layer.borderWidth = 1
            button.titleLabel?.font = AppFont.jp(size: 11, weight: .bold)
            var configuration = UIButton.Configuration.plain()
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8)
            button.configuration = configuration
        }
        retroClickWheelFolderButton.setTitle("戻る", for: .normal)
        retroClickWheelWordButton.setTitle("単語", for: .normal)

        retroKeypadView.addSubview(retroKeypadGrid)

        retroShellView.addSubview(retroSpeakerView)
        retroShellView.addSubview(retroAntennaView)
        retroShellView.addSubview(retroAntennaTipView)
        retroShellView.addSubview(retroClickWheelView)
        retroShellView.addSubview(retroBadgeLabel)
        retroShellView.addSubview(retroScreenView)
        retroShellView.addSubview(retroKeypadView)

        retroClickWheelView.addSubview(retroClickWheelVerticalDivider)
        retroClickWheelView.addSubview(retroClickWheelHorizontalDivider)
        retroClickWheelView.addSubview(retroClickWheelCenterView)
        retroClickWheelView.addSubview(retroClickWheelFolderButton)
        retroClickWheelView.addSubview(retroClickWheelWordButton)

        view.addSubview(retroShellView)

        retroShellBottomConstraint = {
            if #available(iOS 15.0, *) {
                return retroShellView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -AppSpacing.s(16))
            }
            return retroShellView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -AppSpacing.s(16))
        }()

        keypadTopConstraint = retroKeypadView.topAnchor.constraint(equalTo: retroScreenView.bottomAnchor, constant: AppSpacing.s(12))
        clickWheelTopConstraint = retroClickWheelView.topAnchor.constraint(equalTo: retroKeypadView.bottomAnchor, constant: AppSpacing.s(16))
        clickWheelBottomConstraint = retroClickWheelView.bottomAnchor.constraint(equalTo: retroShellView.bottomAnchor, constant: -AppSpacing.s(16))
        screenBottomConstraint = retroScreenView.bottomAnchor.constraint(equalTo: retroShellView.bottomAnchor, constant: -AppSpacing.s(16))

        NSLayoutConstraint.activate([
            retroShellView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: AppSpacing.s(36)),
            retroShellView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AppSpacing.s(28)),
            retroShellView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AppSpacing.s(28)),
            retroShellBottomConstraint!,

            retroSpeakerView.topAnchor.constraint(equalTo: retroShellView.topAnchor, constant: AppSpacing.s(12)),
            retroSpeakerView.centerXAnchor.constraint(equalTo: retroShellView.centerXAnchor),
            retroSpeakerView.widthAnchor.constraint(equalToConstant: 72),
            retroSpeakerView.heightAnchor.constraint(equalToConstant: 6),

            retroAntennaView.leadingAnchor.constraint(equalTo: retroShellView.leadingAnchor, constant: AppSpacing.s(44)),
            retroAntennaView.topAnchor.constraint(equalTo: retroShellView.topAnchor, constant: -AppSpacing.s(60)),
            retroAntennaView.widthAnchor.constraint(equalToConstant: 20),
            retroAntennaView.heightAnchor.constraint(equalToConstant: 85),

            retroAntennaTipView.centerXAnchor.constraint(equalTo: retroAntennaView.centerXAnchor),
            retroAntennaTipView.bottomAnchor.constraint(equalTo: retroAntennaView.topAnchor, constant: AppSpacing.s(4)),
            retroAntennaTipView.widthAnchor.constraint(equalToConstant: 24),
            retroAntennaTipView.heightAnchor.constraint(equalToConstant: 24),

            retroBadgeLabel.centerYAnchor.constraint(equalTo: retroSpeakerView.centerYAnchor),
            retroBadgeLabel.trailingAnchor.constraint(equalTo: retroShellView.trailingAnchor, constant: -AppSpacing.s(16)),
            retroBadgeLabel.widthAnchor.constraint(equalToConstant: 44),
            retroBadgeLabel.heightAnchor.constraint(equalToConstant: 20),

            retroScreenView.topAnchor.constraint(equalTo: retroSpeakerView.bottomAnchor, constant: AppSpacing.s(4)),
            retroScreenView.leadingAnchor.constraint(equalTo: retroShellView.leadingAnchor, constant: AppSpacing.s(12)),
            retroScreenView.trailingAnchor.constraint(equalTo: retroShellView.trailingAnchor, constant: -AppSpacing.s(12)),

            keypadTopConstraint!,
            retroKeypadView.leadingAnchor.constraint(equalTo: retroShellView.leadingAnchor, constant: AppSpacing.s(16)),
            retroKeypadView.trailingAnchor.constraint(equalTo: retroShellView.trailingAnchor, constant: -AppSpacing.s(16)),

            clickWheelTopConstraint!,
            retroClickWheelView.centerXAnchor.constraint(equalTo: retroShellView.centerXAnchor),
            clickWheelBottomConstraint!,

            retroClickWheelCenterView.centerXAnchor.constraint(equalTo: retroClickWheelView.centerXAnchor),
            retroClickWheelCenterView.centerYAnchor.constraint(equalTo: retroClickWheelView.centerYAnchor),
            retroClickWheelCenterView.widthAnchor.constraint(equalToConstant: 48),
            retroClickWheelCenterView.heightAnchor.constraint(equalToConstant: 48),

            retroClickWheelVerticalDivider.centerXAnchor.constraint(equalTo: retroClickWheelView.centerXAnchor),
            retroClickWheelVerticalDivider.topAnchor.constraint(equalTo: retroClickWheelView.topAnchor, constant: AppSpacing.s(18)),
            retroClickWheelVerticalDivider.bottomAnchor.constraint(equalTo: retroClickWheelView.bottomAnchor, constant: -AppSpacing.s(18)),
            retroClickWheelVerticalDivider.widthAnchor.constraint(equalToConstant: 2),

            retroClickWheelHorizontalDivider.centerYAnchor.constraint(equalTo: retroClickWheelView.centerYAnchor),
            retroClickWheelHorizontalDivider.leadingAnchor.constraint(equalTo: retroClickWheelView.leadingAnchor, constant: AppSpacing.s(18)),
            retroClickWheelHorizontalDivider.trailingAnchor.constraint(equalTo: retroClickWheelView.trailingAnchor, constant: -AppSpacing.s(18)),
            retroClickWheelHorizontalDivider.heightAnchor.constraint(equalToConstant: 2),

            retroClickWheelFolderButton.centerYAnchor.constraint(equalTo: retroClickWheelView.centerYAnchor),
            retroClickWheelFolderButton.centerXAnchor.constraint(equalTo: retroClickWheelView.leadingAnchor, constant: AppSpacing.s(35)),
            retroClickWheelFolderButton.widthAnchor.constraint(equalToConstant: 50),
            retroClickWheelFolderButton.heightAnchor.constraint(equalToConstant: 32),

            retroClickWheelWordButton.centerYAnchor.constraint(equalTo: retroClickWheelView.centerYAnchor),
            retroClickWheelWordButton.centerXAnchor.constraint(equalTo: retroClickWheelView.trailingAnchor, constant: -AppSpacing.s(35)),
            retroClickWheelWordButton.widthAnchor.constraint(equalToConstant: 50),
            retroClickWheelWordButton.heightAnchor.constraint(equalToConstant: 32),

            retroKeypadGrid.topAnchor.constraint(equalTo: retroKeypadView.topAnchor, constant: AppSpacing.s(6)),
            retroKeypadGrid.leadingAnchor.constraint(equalTo: retroKeypadView.leadingAnchor, constant: AppSpacing.s(12)),
            retroKeypadGrid.trailingAnchor.constraint(equalTo: retroKeypadView.trailingAnchor, constant: -AppSpacing.s(12)),
            retroKeypadGrid.bottomAnchor.constraint(equalTo: retroKeypadView.bottomAnchor, constant: -AppSpacing.s(6)),

        ])

        let screenMinHeight = retroScreenView.heightAnchor.constraint(greaterThanOrEqualToConstant: 160)
        screenMinHeight.priority = .defaultLow
        screenMinHeight.isActive = true

        let keypadPreferredHeight = retroKeypadView.heightAnchor.constraint(equalToConstant: 140)
        keypadPreferredHeight.priority = .defaultHigh
        keypadPreferredHeight.isActive = true
        let keypadMaxHeight = retroKeypadView.heightAnchor.constraint(lessThanOrEqualToConstant: 150)
        keypadMaxHeight.priority = .required
        keypadMaxHeight.isActive = true
        let keypadMinHeight = retroKeypadView.heightAnchor.constraint(greaterThanOrEqualToConstant: 96)
        keypadMinHeight.priority = .defaultLow
        keypadMinHeight.isActive = true

        let wheelPreferredSize = retroClickWheelView.heightAnchor.constraint(equalToConstant: 130)
        wheelPreferredSize.priority = .defaultHigh
        wheelPreferredSize.isActive = true
        let wheelMaxHeight = retroClickWheelView.heightAnchor.constraint(lessThanOrEqualToConstant: 140)
        wheelMaxHeight.priority = .required
        wheelMaxHeight.isActive = true
        let wheelMinHeight = retroClickWheelView.heightAnchor.constraint(greaterThanOrEqualToConstant: 110)
        wheelMinHeight.priority = .defaultLow
        wheelMinHeight.isActive = true
        retroClickWheelView.widthAnchor.constraint(equalTo: retroClickWheelView.heightAnchor).isActive = true

        let folderWidth = retroFolderButton.widthAnchor.constraint(greaterThanOrEqualTo: retroWordButton.widthAnchor, multiplier: 1.2)
        folderWidth.priority = .defaultHigh
        folderWidth.isActive = true
        let equalSortWidth = retroSortButton.widthAnchor.constraint(equalTo: retroFolderButton.widthAnchor)
        let equalAddWidth = retroAddButton.widthAnchor.constraint(equalTo: retroFolderButton.widthAnchor)
        equalSortWidth.isActive = true
        equalAddWidth.isActive = true

        retroFolderButton.addTarget(self, action: #selector(openAddSet), for: .touchUpInside)
        retroWordButton.addTarget(self, action: #selector(openShareMenu), for: .touchUpInside)
        retroSortButton.addTarget(self, action: #selector(openSortMenu), for: .touchUpInside)
        retroAddButton.addTarget(self, action: #selector(openWhichView), for: .touchUpInside)
        retroClickWheelFolderButton.addTarget(self, action: #selector(openFolderView), for: .touchUpInside)
        retroClickWheelWordButton.addTarget(self, action: #selector(openWordMenuFromClickWheel), for: .touchUpInside)
    }

    private func configureRetroNavButton(_ button: UIButton, title: String, symbolName: String) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.configuration = nil
        button.setTitle(nil, for: .normal)
        button.setImage(nil, for: .normal)
        button.accessibilityLabel = title
        button.clipsToBounds = false
        button.layer.cornerRadius = 28
        button.layer.borderWidth = 3

        let iconView = UIImageView()
        iconView.tag = RetroNavTag.icon
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFit
        iconView.image = UIImage(
            systemName: symbolName,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 23, weight: .bold)
        )?.withRenderingMode(.alwaysTemplate)

        let titleLabel = UILabel()
        titleLabel.tag = RetroNavTag.label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = title
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 1
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.72

        let stack = UIStackView(arrangedSubviews: [iconView, titleLabel])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = AppSpacing.s(7)
        stack.isUserInteractionEnabled = false

        button.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: button.leadingAnchor, constant: AppSpacing.s(8)),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: button.trailingAnchor, constant: -AppSpacing.s(8)),
            stack.topAnchor.constraint(greaterThanOrEqualTo: button.topAnchor, constant: AppSpacing.s(8)),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: button.bottomAnchor, constant: -AppSpacing.s(8)),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24)
        ])

        button.addTarget(self, action: #selector(retroNavButtonTouchDown(_:)), for: [.touchDown, .touchDragEnter])
        button.addTarget(self, action: #selector(retroNavButtonTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
    }

    private func styleRetroNavButton(_ button: UIButton, selected: Bool = false) {
        let palette = ThemeManager.palette()
        let fillColor = selected ? palette.accent.withAlphaComponent(0.72) : palette.surfaceAlt.withAlphaComponent(0.96)
        let contentColor = palette.text

        button.backgroundColor = fillColor
        button.tintColor = contentColor
        button.layer.cornerRadius = 28
        button.layer.borderWidth = 3
        button.layer.borderColor = palette.border.cgColor
        button.layer.shadowColor = palette.border.cgColor
        button.layer.shadowOpacity = selected ? 0.22 : 0.15
        button.layer.shadowOffset = CGSize(width: 0, height: 4)
        button.layer.shadowRadius = 0

        if let iconView = button.viewWithTag(RetroNavTag.icon) as? UIImageView {
            iconView.tintColor = contentColor
            iconView.isHidden = false
        }
        if let titleLabel = button.viewWithTag(RetroNavTag.label) as? UILabel {
            titleLabel.font = AppFont.jp(size: 12, weight: .bold)
            titleLabel.textColor = contentColor
        }
    }

    @objc private func retroNavButtonTouchDown(_ sender: UIButton) {
        UIView.animate(withDuration: 0.08, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction]) {
            sender.transform = CGAffineTransform(scaleX: 0.95, y: 0.95).translatedBy(x: 0, y: 2)
            sender.layer.shadowOffset = CGSize(width: 0, height: 1)
            sender.layer.shadowOpacity = 0.1
        }
    }

    @objc private func retroNavButtonTouchUp(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction]) {
            sender.transform = .identity
            sender.layer.shadowOffset = CGSize(width: 0, height: 4)
            sender.layer.shadowOpacity = 0.15
        }
    }

    private func configureThemeHeader() {
        themeHeader.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: themeHeaderHeight)
        themeHeader.translatesAutoresizingMaskIntoConstraints = false
        selectedSetsPanel.translatesAutoresizingMaskIntoConstraints = false

        themeTitleLabel.text = "テーマ"
        themeTitleLabel.textAlignment = .left
        selectedSetsTitleLabel.text = "追加したセット"
        selectedSetsTitleLabel.textAlignment = .left
        selectedSetsEmptyLabel.text = "セットをタップすると上から追加されます"
        selectedSetsEmptyLabel.textAlignment = .left
        selectedSetsEmptyLabel.numberOfLines = 0

        selectedSetsStack.axis = .vertical
        selectedSetsStack.spacing = AppSpacing.s(8)
        selectedSetsStack.alignment = .fill
        selectedSetsStack.distribution = .fill
        selectedSetsStack.translatesAutoresizingMaskIntoConstraints = false

        themeStack.axis = .horizontal
        themeStack.spacing = AppSpacing.s(12)
        themeStack.alignment = .center
        themeStack.distribution = .fillEqually
        themeStack.translatesAutoresizingMaskIntoConstraints = false

        themeButtons = AppTheme.allCases.enumerated().map { index, theme in
            let button = UIButton(type: .system)
            button.tag = index
            button.layer.cornerRadius = 16
            button.layer.borderWidth = 2
            button.addTarget(self, action: #selector(selectTheme(_:)), for: .touchUpInside)
            return button
        }
        themeButtons.forEach { themeStack.addArrangedSubview($0) }

        selectedSetsPanel.addSubview(selectedSetsTitleLabel)
        selectedSetsPanel.addSubview(selectedSetsEmptyLabel)
        selectedSetsPanel.addSubview(selectedSetsStack)
        themeHeader.addSubview(themeTitleLabel)
        themeHeader.addSubview(themeStack)
        selectedSetsTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        selectedSetsEmptyLabel.translatesAutoresizingMaskIntoConstraints = false
        themeTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            selectedSetsTitleLabel.topAnchor.constraint(equalTo: selectedSetsPanel.topAnchor, constant: AppSpacing.s(12)),
            selectedSetsTitleLabel.leadingAnchor.constraint(equalTo: selectedSetsPanel.leadingAnchor, constant: AppSpacing.s(16)),
            selectedSetsTitleLabel.trailingAnchor.constraint(equalTo: selectedSetsPanel.trailingAnchor, constant: -AppSpacing.s(16)),

            selectedSetsEmptyLabel.topAnchor.constraint(equalTo: selectedSetsTitleLabel.bottomAnchor, constant: AppSpacing.s(8)),
            selectedSetsEmptyLabel.leadingAnchor.constraint(equalTo: selectedSetsPanel.leadingAnchor, constant: AppSpacing.s(16)),
            selectedSetsEmptyLabel.trailingAnchor.constraint(equalTo: selectedSetsPanel.trailingAnchor, constant: -AppSpacing.s(16)),

            selectedSetsStack.topAnchor.constraint(equalTo: selectedSetsTitleLabel.bottomAnchor, constant: AppSpacing.s(8)),
            selectedSetsStack.leadingAnchor.constraint(equalTo: selectedSetsPanel.leadingAnchor, constant: AppSpacing.s(16)),
            selectedSetsStack.trailingAnchor.constraint(equalTo: selectedSetsPanel.trailingAnchor, constant: -AppSpacing.s(16)),

            themeTitleLabel.topAnchor.constraint(equalTo: themeHeader.topAnchor, constant: AppSpacing.s(12)),
            themeTitleLabel.leadingAnchor.constraint(equalTo: themeHeader.leadingAnchor, constant: AppSpacing.s(20)),
            themeTitleLabel.trailingAnchor.constraint(equalTo: themeHeader.trailingAnchor, constant: -AppSpacing.s(20)),

            themeStack.topAnchor.constraint(equalTo: themeTitleLabel.bottomAnchor, constant: AppSpacing.s(12)),
            themeStack.leadingAnchor.constraint(equalTo: themeHeader.leadingAnchor, constant: AppSpacing.s(20)),
            themeStack.trailingAnchor.constraint(equalTo: themeHeader.trailingAnchor, constant: -AppSpacing.s(20)),
            themeStack.heightAnchor.constraint(equalToConstant: 36),
        ])

        headerContainer.addSubview(selectedSetsPanel)
        headerContainer.addSubview(themeHeader)
        tableView.tableHeaderView = headerContainer
        updateSelectedSetsPanel(animated: false, insertedSetID: nil)
    }

    private func reloadData() {
        reloadTaskID += 1
        let currentTaskID = reloadTaskID
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let allSets = SetStore.loadSets()
            let loadedSets: [SavedSet]
            if self.showsAll {
                loadedSets = allSets
            } else {
                loadedSets = allSets.filter { $0.folderID == self.folderID }
            }
            let words = self.loadSavedWords()
            let loadedWordsByID = Dictionary(uniqueKeysWithValues: words.map { ($0.id, $0) })
            let loadedSetWordCount = Dictionary(uniqueKeysWithValues: loadedSets.map { set in
                let count = set.wordIDs.reduce(into: 0) { partialResult, wordID in
                    if loadedWordsByID[wordID] != nil {
                        partialResult += 1
                    }
                }
                return (set.id, count)
            })
            DispatchQueue.main.async { [weak self] in
                guard let self, self.reloadTaskID == currentTaskID else { return }
                self.sets = loadedSets
                self.selectedSets = self.selectedSets.compactMap { selected in
                    loadedSets.first { $0.id == selected.id }
                }
                self.wordsByID = loadedWordsByID
                self.setWordCountByID = loadedSetWordCount
                self.applyFilterAndReload()
            }
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return displayedSets().count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseID = "setCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseID)
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: reuseID)
        let set = displayedSets()[indexPath.row]
        let isSelected = selectedSets.contains { $0.id == set.id }
        cell.accessibilityIdentifier = set.id
        let count = wordCount(for: set)
        cell.textLabel?.text = set.name
        cell.detailTextLabel?.text = "単語 \(count) 個"
        cell.accessoryType = .none
        cell.textLabel?.font = AppFont.jp(size: 18, weight: .bold)
        cell.detailTextLabel?.font = AppFont.jp(size: 14)
        let palette = ThemeManager.palette()
        cell.backgroundColor = .clear
        cell.textLabel?.textColor = isSelected ? .white : palette.text
        cell.detailTextLabel?.textColor = isSelected ? UIColor.white.withAlphaComponent(0.82) : palette.mutedText
        let accessoryImageName = isSelected ? "checkmark.circle.fill" : "plus.circle"
        let accessoryView = UIImageView(image: UIImage(systemName: accessoryImageName))
        accessoryView.tintColor = isSelected ? .white : palette.accentStrong
        accessoryView.contentMode = .scaleAspectFit
        accessoryView.frame = CGRect(x: 0, y: 0, width: 24, height: 24)
        cell.accessoryView = accessoryView
        applyRetroCellStyle(cell, isSelected: isSelected)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        handleSelection(at: indexPath)
    }

    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath)
    -> UISwipeActionsConfiguration? {
        guard indexPath.row < displayedSetCache.count else { return nil }
        let setID = displayedSetCache[indexPath.row].id
        let move = UIContextualAction(style: .normal, title: "フォルダー") { [weak self] _, _, completion in
            self?.showMoveSetSheet(for: indexPath)
            completion(true)
        }
        move.backgroundColor = .systemBlue
        let delete = UIContextualAction(style: .destructive, title: "削除") { [weak self] _, _, completion in
            self?.deleteSet(id: setID)
            completion(true)
        }
        return UISwipeActionsConfiguration(actions: [delete, move])
    }

    func tableView(_ tableView: UITableView, willBeginEditingRowAt indexPath: IndexPath) {
        tapGesture.isEnabled = false
    }

    func tableView(_ tableView: UITableView, didEndEditingRowAt indexPath: IndexPath?) {
        tapGesture.isEnabled = true
    }

    @objc private func openAddSet() {
        let controller = SetCreateViewController(folderID: folderID)
        navigationController?.pushViewController(controller, animated: true)
    }

    @objc private func openWordList() {
        openWordListForEditing(false, hideActions: true, showHideButton: true)
    }

    @objc private func openShareMenu() {
        let sets = displayedSets()
        guard !sets.isEmpty else {
            showAlert(title: "共有できるセットがありません", message: "先にセットを作成してください。")
            return
        }
        var actions = sets.map { set in
            UnifiedModalAction(title: set.name) { [weak self] in
                self?.shareSet(set)
            }
        }
        actions.append(UnifiedModalAction(title: "キャンセル", style: .cancel))
        presentUnifiedModal(title: "共有するセット",
                            message: "AirDropや共有先へ送信します。",
                            actions: actions)
    }

    private func shareSet(_ set: SavedSet) {
        guard !set.wordIDs.isEmpty else {
            showAlert(title: "共有エラー", message: "このセットには共有できる単語がありません。")
            return
        }
        guard let fileURL = buildWordListPDF(for: set) else {
            showAlert(title: "共有エラー", message: "データの作成に失敗しました。")
            return
        }
        let activity = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        if let popover = activity.popoverPresentationController {
            popover.sourceView = retroClickWheelWordButton
            popover.sourceRect = retroClickWheelWordButton.bounds
        }
        present(activity, animated: true)
    }

    private func buildWordListPDF(for set: SavedSet) -> URL? {
        let allWords = loadSavedWords()
        let wordMap = Dictionary(uniqueKeysWithValues: allWords.map { ($0.id, $0) })
        let words = set.wordIDs.compactMap { wordMap[$0] }
        guard !words.isEmpty else { return nil }

        let safeName = sanitizeFileName(set.name.isEmpty ? "set" : set.name)
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(safeName)-word-list.pdf")

        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8) // A4 @72dpi
        let margin: CGFloat = 32
        let rowHeight: CGFloat = 26
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        do {
            try renderer.writePDF(to: fileURL) { context in
                let titleFont = AppFont.jp(size: 18, weight: .bold)
                let metaFont = AppFont.jp(size: 11)
                let headerFont = AppFont.jp(size: 12, weight: .bold)
                let bodyFont = AppFont.jp(size: 11)
                let textColor = UIColor.black

                let tableTopStart: CGFloat = margin + 72
                let tableBottom: CGFloat = pageRect.height - margin
                let tableWidth = pageRect.width - (margin * 2)
                let noWidth: CGFloat = 44
                let englishWidth = (tableWidth - noWidth) * 0.5
                let japaneseWidth = tableWidth - noWidth - englishWidth

                var currentY: CGFloat = 0
                var row = 0
                var pageNumber = 1

                func drawPageHeader() {
                    context.beginPage()

                    let title = set.name.isEmpty ? "Word List" : "\(set.name) Word List"
                    title.draw(
                        at: CGPoint(x: margin, y: margin),
                        withAttributes: [
                            .font: titleFont,
                            .foregroundColor: textColor
                        ]
                    )

                    let meta = "Total: \(words.count)   Page: \(pageNumber)"
                    meta.draw(
                        at: CGPoint(x: margin, y: margin + 26),
                        withAttributes: [
                            .font: metaFont,
                            .foregroundColor: textColor
                        ]
                    )

                    currentY = tableTopStart

                    UIColor(white: 0.93, alpha: 1).setFill()
                    UIBezierPath(rect: CGRect(x: margin, y: currentY, width: tableWidth, height: rowHeight)).fill()
                    UIColor.black.setStroke()
                    UIBezierPath(rect: CGRect(x: margin, y: currentY, width: tableWidth, height: rowHeight)).stroke()

                    let noRect = CGRect(x: margin + 6, y: currentY + 6, width: noWidth - 12, height: rowHeight - 12)
                    let enRect = CGRect(x: margin + noWidth + 6, y: currentY + 6, width: englishWidth - 12, height: rowHeight - 12)
                    let jaRect = CGRect(x: margin + noWidth + englishWidth + 6, y: currentY + 6, width: japaneseWidth - 12, height: rowHeight - 12)
                    "No".draw(in: noRect, withAttributes: [.font: headerFont, .foregroundColor: textColor])
                    "English".draw(in: enRect, withAttributes: [.font: headerFont, .foregroundColor: textColor])
                    "日本語".draw(in: jaRect, withAttributes: [.font: headerFont, .foregroundColor: textColor])

                    currentY += rowHeight
                }

                drawPageHeader()

                while row < words.count {
                    if currentY + rowHeight > tableBottom {
                        pageNumber += 1
                        drawPageHeader()
                    }

                    let word = words[row]
                    if row.isMultiple(of: 2) {
                        UIColor(white: 0.98, alpha: 1).setFill()
                        UIBezierPath(rect: CGRect(x: margin, y: currentY, width: tableWidth, height: rowHeight)).fill()
                    }
                    UIColor.black.setStroke()
                    UIBezierPath(rect: CGRect(x: margin, y: currentY, width: tableWidth, height: rowHeight)).stroke()

                    let noText = "\(row + 1)"
                    let noRect = CGRect(x: margin + 6, y: currentY + 6, width: noWidth - 12, height: rowHeight - 12)
                    noText.draw(in: noRect, withAttributes: [.font: bodyFont, .foregroundColor: textColor])

                    let englishRect = CGRect(x: margin + noWidth + 6, y: currentY + 6, width: englishWidth - 12, height: rowHeight - 12)
                    word.english.draw(
                        in: englishRect,
                        withAttributes: [.font: bodyFont, .foregroundColor: textColor]
                    )

                    let japaneseRect = CGRect(x: margin + noWidth + englishWidth + 6, y: currentY + 6, width: japaneseWidth - 12, height: rowHeight - 12)
                    word.japanese.draw(
                        in: japaneseRect,
                        withAttributes: [.font: bodyFont, .foregroundColor: textColor]
                    )

                    currentY += rowHeight
                    row += 1
                }
            }
            return fileURL
        } catch {
            return nil
        }
    }

    private func showAlert(title: String, message: String) {
        let presentBlock = { [weak self] in
            self?.presentUnifiedModal(title: title,
                                      message: message,
                                      actions: [UnifiedModalAction(title: "OK")])
        }
        if let presented = presentedViewController as? UnifiedModalViewController {
            presented.dismiss(animated: false) {
                presentBlock()
            }
            return
        }
        guard presentedViewController == nil else { return }
        presentBlock()
    }

    private func sanitizeFileName(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        let scalars = name.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        let trimmed = String(scalars).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return trimmed.isEmpty ? "set" : trimmed
    }

    private func openWordListForEditing(_ editing: Bool,
                                        hideActions: Bool,
                                        showHideButton: Bool = false) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let listVC = storyboard.instantiateViewController(withIdentifier: "ListTableViewController")
                as? ListTableViewController else {
            return
        }
        listVC.startEditing = editing
        listVC.hideTestAndAdd = hideActions
        listVC.showHideButton = showHideButton
        navigationController?.pushViewController(listVC, animated: true)
    }

    @objc private func openWordMenuFromClickWheel() {
        showWordMenuModal()
    }

    private func openAddWord() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let addVC = storyboard.instantiateViewController(withIdentifier: "AddViewController")
        navigationController?.pushViewController(addVC, animated: true)
    }

    @objc private func openWhichView() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let whichVC = storyboard.instantiateViewController(withIdentifier: "WhichViewController")
        navigationController?.pushViewController(whichVC, animated: true)
    }

    @objc private func openFolderView() {
        guard let navigationController else { return }
        if let target = navigationController.viewControllers.first(where: { $0 is FolderViewController }) {
            navigationController.popToViewController(target, animated: true)
            return
        }
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let controller = storyboard.instantiateViewController(withIdentifier: "FolderViewController") as? FolderViewController {
            navigationController.pushViewController(controller, animated: true)
        }
    }

    @objc private func backToFolders() {
        openFolderView()
    }

    @objc private func selectTheme(_ sender: UIButton) {
        let themes = AppTheme.allCases
        guard sender.tag >= 0, sender.tag < themes.count else { return }
        ThemeManager.setTheme(themes[sender.tag])
        updateThemeSelection()
    }

    private func applyTheme() {
        let palette = ThemeManager.palette()
        ThemeManager.applyBackground(to: view)
        ThemeManager.applyNavigationAppearance(to: navigationController)
        ThemeManager.applySearchBar(searchController.searchBar)

        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 20, right: 0)
        tableView.showsVerticalScrollIndicator = false
        tableView.separatorColor = palette.border
        emptyLabel.font = AppFont.jp(size: 16)
        emptyLabel.textColor = palette.mutedText

        searchContainer.backgroundColor = palette.surface
        searchContainer.layer.cornerRadius = 12
        searchContainer.layer.borderWidth = 1.5
        searchContainer.layer.borderColor = palette.border.cgColor

        retroShellView.backgroundColor = UIColor(white: 0.18, alpha: 1.0)
        retroShellView.layer.cornerRadius = 36
        retroShellView.layer.borderWidth = 0.5
        retroShellView.layer.borderColor = UIColor(white: 0.2, alpha: 1.0).cgColor
        retroShellView.layer.shadowColor = palette.border.cgColor
        retroShellView.layer.shadowOpacity = 0.18
        retroShellView.layer.shadowOffset = CGSize(width: 0, height: 6)
        retroShellView.layer.shadowRadius = 12

        retroScreenView.backgroundColor = palette.accentStrong
        retroScreenView.layer.cornerRadius = 0
        retroScreenView.layer.borderWidth = 8
        retroScreenView.layer.borderColor = UIColor.darkGray.cgColor
        retroScreenView.clipsToBounds = true

        retroSpeakerView.backgroundColor = palette.border.withAlphaComponent(0.7)
        retroSpeakerView.layer.cornerRadius = 3

        retroAntennaView.backgroundColor = UIColor.black
        retroAntennaView.layer.cornerRadius = 0
        retroAntennaView.layer.borderWidth = 0
        retroAntennaTipView.backgroundColor = UIColor.systemGray
        retroAntennaTipView.layer.cornerRadius = 12

        retroClickWheelView.backgroundColor = UIColor.systemGray5
        retroClickWheelView.layer.borderWidth = 2
        retroClickWheelView.layer.borderColor = UIColor.systemGray3.cgColor
        retroClickWheelCenterView.backgroundColor = UIColor.systemGray4
        retroClickWheelVerticalDivider.backgroundColor = UIColor.systemGray2
        retroClickWheelHorizontalDivider.backgroundColor = UIColor.systemGray2
        ThemeManager.stylePixelOutlineButton(retroClickWheelFolderButton)
        ThemeManager.stylePixelOutlineButton(retroClickWheelWordButton)

        retroKeypadView.backgroundColor = UIColor(white: 0.18, alpha: 1.0)
        retroKeypadView.layer.cornerRadius = 22
        retroKeypadView.layer.borderWidth = 2
        retroKeypadView.layer.borderColor = palette.border.cgColor

        styleRetroNavButton(retroFolderButton)
        styleRetroNavButton(retroWordButton)
        styleRetroNavButton(retroSortButton)
        styleRetroNavButton(retroAddButton, selected: true)

        retroBadgeLabel.font = AppFont.title(size: 9)
        retroBadgeLabel.textColor = palette.text
        retroBadgeLabel.backgroundColor = palette.surfaceAlt
        retroBadgeLabel.layer.cornerRadius = 8
        retroBadgeLabel.layer.borderWidth = 1
        retroBadgeLabel.layer.borderColor = palette.border.cgColor
        retroBadgeLabel.clipsToBounds = true

        themeHeader.backgroundColor = palette.surface
        themeHeader.layer.cornerRadius = 16
        themeHeader.layer.borderWidth = 2
        themeHeader.layer.borderColor = palette.border.cgColor
        themeHeader.clipsToBounds = true
        themeTitleLabel.font = AppFont.jp(size: 16, weight: .bold)
        themeTitleLabel.textColor = palette.text

        for (index, button) in themeButtons.enumerated() {
            let theme = AppTheme.allCases[index]
            button.backgroundColor = ThemeManager.palette(for: theme).accent
        }
        updateThemeSelection()
        updateSelectedSetsPanel(animated: false, insertedSetID: nil)
        updateWordMenuModalTheme()
        tableView.reloadData()
    }

    private func showWordMenuModal() {
        guard wordMenuOverlay == nil else { return }
        let overlay = UIControl()
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.addTarget(self, action: #selector(dismissWordMenuModal), for: .touchUpInside)
        overlay.accessibilityViewIsModal = true

        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "単語"
        titleLabel.textAlignment = .center

        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = AppSpacing.s(8)

        let listButton = makeWordMenuButton(title: "単語一覧", action: #selector(handleWordMenuList))
        let addButton = makeWordMenuButton(title: "単語追加", action: #selector(handleWordMenuAdd))
        let editButton = makeWordMenuButton(title: "編集", action: #selector(handleWordMenuEdit))
        let cancelButton = makeWordMenuButton(title: "キャンセル", action: #selector(dismissWordMenuModal))

        [listButton, addButton, editButton, cancelButton].forEach { button in
            stack.addArrangedSubview(button)
            button.heightAnchor.constraint(equalToConstant: 36).isActive = true
        }

        container.addSubview(titleLabel)
        container.addSubview(stack)
        overlay.addSubview(container)
        view.addSubview(overlay)

        NSLayoutConstraint.activate([
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            container.centerXAnchor.constraint(equalTo: retroClickWheelView.centerXAnchor),
            container.centerYAnchor.constraint(equalTo: retroClickWheelView.centerYAnchor, constant: -110),
            container.widthAnchor.constraint(equalToConstant: 240),
            container.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: AppSpacing.s(24)),
            container.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -AppSpacing.s(24)),

            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: AppSpacing.s(16)),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: AppSpacing.s(16)),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -AppSpacing.s(16)),

            stack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: AppSpacing.s(12)),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: AppSpacing.s(16)),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -AppSpacing.s(16)),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -AppSpacing.s(16)),
        ])

        wordMenuOverlay = overlay
        wordMenuContainer = container
        wordMenuTitleLabel = titleLabel
        wordMenuButtons = [listButton, addButton, editButton, cancelButton]
        updateWordMenuModalTheme()

        overlay.alpha = 0
        container.alpha = 0
        container.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseOut]) {
            overlay.alpha = 1
            container.alpha = 1
            container.transform = .identity
        }
    }

    @objc private func dismissWordMenuModal() {
        guard let overlay = wordMenuOverlay, let container = wordMenuContainer else { return }
        UIView.animate(withDuration: 0.15, delay: 0, options: [.curveEaseIn]) {
            overlay.alpha = 0
            container.alpha = 0
            container.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        } completion: { [weak self] _ in
            overlay.removeFromSuperview()
            self?.wordMenuOverlay = nil
            self?.wordMenuContainer = nil
            self?.wordMenuTitleLabel = nil
            self?.wordMenuButtons = []
        }
    }

    @objc private func handleWordMenuList() {
        dismissWordMenuModal()
        openWordListForEditing(false, hideActions: true)
    }

    @objc private func handleWordMenuAdd() {
        dismissWordMenuModal()
        openAddWord()
    }

    @objc private func handleWordMenuEdit() {
        dismissWordMenuModal()
        openWordListForEditing(true, hideActions: true)
    }

    private func makeWordMenuButton(title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(title, for: .normal)
        button.addTarget(self, action: action, for: .touchUpInside)
        button.titleLabel?.font = AppFont.jp(size: 14, weight: .bold)
        var configuration = UIButton.Configuration.plain()
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8)
        button.configuration = configuration
        button.layer.borderWidth = 2
        button.layer.cornerRadius = 0
        button.layer.masksToBounds = true
        return button
    }

    private func updateWordMenuModalTheme() {
        guard let overlay = wordMenuOverlay,
              let container = wordMenuContainer,
              let titleLabel = wordMenuTitleLabel else { return }
        let palette = ThemeManager.palette()
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        container.backgroundColor = palette.surface
        container.layer.borderWidth = 2
        container.layer.borderColor = palette.border.cgColor
        container.layer.cornerRadius = 0
        titleLabel.font = AppFont.jp(size: 16, weight: .bold)
        titleLabel.textColor = palette.text
        wordMenuButtons.forEach { button in
            button.backgroundColor = palette.surfaceAlt
            button.layer.borderColor = palette.border.cgColor
            button.setTitleColor(palette.text, for: .normal)
        }
    }

    private func updateSelectedSetsPanel(animated: Bool, insertedSetID: String?) {
        let palette = ThemeManager.palette()
        selectedSetsPanel.backgroundColor = palette.surface.withAlphaComponent(0.96)
        selectedSetsPanel.layer.cornerRadius = 16
        selectedSetsPanel.layer.borderWidth = 1.5
        selectedSetsPanel.layer.borderColor = palette.border.cgColor

        selectedSetsTitleLabel.font = AppFont.jp(size: 14, weight: .bold)
        selectedSetsTitleLabel.textColor = palette.text
        selectedSetsEmptyLabel.font = AppFont.jp(size: 12, weight: .bold)
        selectedSetsEmptyLabel.textColor = palette.mutedText
        selectedSetsEmptyLabel.isHidden = !selectedSets.isEmpty
        selectedSetsStack.isHidden = selectedSets.isEmpty

        selectedSetsStack.arrangedSubviews.forEach { view in
            selectedSetsStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        for (index, set) in selectedSets.enumerated() {
            let row = makeSelectedSetRow(set: set, index: index, palette: palette)
            selectedSetsStack.addArrangedSubview(row)
            row.heightAnchor.constraint(equalToConstant: 40).isActive = true

            if animated, set.id == insertedSetID {
                row.alpha = 0
                row.transform = CGAffineTransform(translationX: 0, y: -10)
                UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseOut]) {
                    row.alpha = 1
                    row.transform = .identity
                }
            }
        }

        updateHeaderLayout()
    }

    private func makeSelectedSetRow(set: SavedSet, index: Int, palette: ThemePalette) -> UIView {
        let row = UIView()
        row.backgroundColor = palette.accent.withAlphaComponent(0.16)
        row.layer.cornerRadius = 12
        row.layer.borderWidth = 1
        row.layer.borderColor = palette.accentStrong.cgColor

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = AppFont.jp(size: 13, weight: .bold)
        label.textColor = palette.text
        label.text = "\(index + 1). \(set.name)"
        label.lineBreakMode = .byTruncatingTail

        let openButton = UIButton(type: .system)
        openButton.translatesAutoresizingMaskIntoConstraints = false
        openButton.tag = index
        openButton.setImage(UIImage(systemName: "play.circle.fill"), for: .normal)
        openButton.tintColor = palette.accentStrong
        openButton.accessibilityLabel = "\(set.name)を開く"
        openButton.addTarget(self, action: #selector(openSelectedSet(_:)), for: .touchUpInside)

        let removeButton = UIButton(type: .system)
        removeButton.translatesAutoresizingMaskIntoConstraints = false
        removeButton.tag = index
        removeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        removeButton.tintColor = palette.accentStrong
        removeButton.accessibilityLabel = "\(set.name)を削除"
        removeButton.addTarget(self, action: #selector(removeSelectedSet(_:)), for: .touchUpInside)

        row.addSubview(label)
        row.addSubview(openButton)
        row.addSubview(removeButton)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: AppSpacing.s(12)),
            label.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            label.trailingAnchor.constraint(equalTo: openButton.leadingAnchor, constant: -AppSpacing.s(8)),

            openButton.trailingAnchor.constraint(equalTo: removeButton.leadingAnchor, constant: -AppSpacing.s(4)),
            openButton.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            openButton.widthAnchor.constraint(equalToConstant: 28),
            openButton.heightAnchor.constraint(equalToConstant: 28),

            removeButton.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -AppSpacing.s(10)),
            removeButton.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            removeButton.widthAnchor.constraint(equalToConstant: 28),
            removeButton.heightAnchor.constraint(equalToConstant: 28),
        ])
        return row
    }

    private func updateHeaderLayout() {
        guard let header = tableView.tableHeaderView else { return }
        let width = tableView.bounds.width
        let selectedHeight = selectedSetsPanelHeight
        let totalHeight = selectedHeight + themeHeaderHeight
        header.frame = CGRect(x: 0, y: 0, width: width, height: totalHeight)
        selectedSetsPanel.frame = CGRect(x: 0, y: 0, width: width, height: selectedHeight)
        themeHeader.frame = CGRect(x: 0, y: selectedHeight, width: width, height: themeHeaderHeight)
        tableView.tableHeaderView = header

        let keyHeight = retroKeypadRowTop.bounds.height
        if keyHeight > 0 {
            retroKeyButtons.forEach { $0.layer.cornerRadius = 0 }
        }
    }

    private var selectedSetsPanelHeight: CGFloat {
        let rowsHeight = selectedSets.isEmpty ? 28 : CGFloat(selectedSets.count) * 40 + CGFloat(max(selectedSets.count - 1, 0)) * AppSpacing.s(8)
        return AppSpacing.s(44) + rowsHeight + AppSpacing.s(16)
    }

    private func updateThemeSelection() {
        let current = ThemeManager.current
        for (index, button) in themeButtons.enumerated() {
            let theme = AppTheme.allCases[index]
            if theme == current {
                button.layer.borderColor = ThemeManager.palette().border.cgColor
                button.layer.shadowColor = ThemeManager.palette().border.cgColor
                button.layer.shadowOpacity = 0.25
                button.layer.shadowOffset = CGSize(width: 0, height: 2)
                button.layer.shadowRadius = 4
            } else {
                button.layer.borderColor = UIColor.clear.cgColor
                button.layer.shadowOpacity = 0
            }
        }
    }

    private func applyRetroCellStyle(_ cell: UITableViewCell, isSelected: Bool) {
        let containerTag = 9911
        let container: UIView
        if let existing = cell.contentView.viewWithTag(containerTag) {
            container = existing
        } else {
            container = UIView()
            container.tag = containerTag
            container.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.insertSubview(container, at: 0)
            NSLayoutConstraint.activate([
                container.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: AppSpacing.s(12)),
                container.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -AppSpacing.s(12)),
                container.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: AppSpacing.s(6)),
                container.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -AppSpacing.s(6)),
            ])
        }

        let palette = ThemeManager.palette()
        container.backgroundColor = isSelected ? palette.accentStrong : palette.surface
        container.layer.cornerRadius = 16
        container.layer.borderWidth = 1.5
        container.layer.borderColor = isSelected ? UIColor.white.withAlphaComponent(0.9).cgColor : palette.border.cgColor
        container.layer.shadowColor = palette.border.cgColor
        container.layer.shadowOpacity = isSelected ? 0.18 : 0.12
        container.layer.shadowOffset = CGSize(width: 0, height: 2)
        container.layer.shadowRadius = 4
        container.layer.masksToBounds = false

        cell.selectionStyle = .none
        cell.contentView.clipsToBounds = false
        cell.clipsToBounds = false
        cell.contentView.sendSubviewToBack(container)
    }

    @objc private func openSortMenu() {
        let actions: [UnifiedModalAction] = [
            UnifiedModalAction(title: "作成順") { [weak self] in
                self?.sortOption = .created
                self?.applyFilterAndReload()
            },
            UnifiedModalAction(title: "名前 A→Z") { [weak self] in
                self?.sortOption = .nameAsc
                self?.applyFilterAndReload()
            },
            UnifiedModalAction(title: "名前 Z→A") { [weak self] in
                self?.sortOption = .nameDesc
                self?.applyFilterAndReload()
            },
            UnifiedModalAction(title: "単語数 少ない→多い") { [weak self] in
                self?.sortOption = .countAsc
                self?.applyFilterAndReload()
            },
            UnifiedModalAction(title: "単語数 多い→少ない") { [weak self] in
                self?.sortOption = .countDesc
                self?.applyFilterAndReload()
            },
            UnifiedModalAction(title: "キャンセル", style: .cancel)
        ]
        presentUnifiedModal(title: "並び替え", message: nil, actions: actions)
    }

    deinit {
        if let observer = themeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        keyboardObservers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    private func displayedSets() -> [SavedSet] {
        return displayedSetCache
    }

    private func sortedSets(_ input: [SavedSet]) -> [SavedSet] {
        switch sortOption {
        case .created:
            return input
        case .nameAsc:
            return input.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .nameDesc:
            return input.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
        case .countAsc:
            return input.sorted { wordCount(for: $0) < wordCount(for: $1) }
        case .countDesc:
            return input.sorted { wordCount(for: $0) > wordCount(for: $1) }
        }
    }

    private func wordCount(for set: SavedSet) -> Int {
        if let cached = setWordCountByID[set.id] {
            return cached
        }
        return set.wordIDs.compactMap { wordsByID[$0] }.count
    }

    @objc private func handleSetRenameLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        let location = gesture.location(in: tableView)
        guard let indexPath = tableView.indexPathForRow(at: location) else { return }
        let set = displayedSets()[indexPath.row]
        let nameField = UITextField()
        nameField.borderStyle = .roundedRect
        nameField.text = set.name
        nameField.placeholder = "セット名"
        presentUnifiedModal(
            title: "名前変更",
            message: nil,
            contentView: nameField,
            actions: [
                UnifiedModalAction(title: "キャンセル", style: .cancel),
                UnifiedModalAction(title: "保存") { [weak self] in
                    guard let self else { return }
                    let name = nameField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    guard !name.isEmpty else { return }
                    if let index = self.sets.firstIndex(where: { $0.id == set.id }) {
                        self.sets[index].name = name
                        SetStore.saveSets(self.sets)
                        self.applyFilterAndReload()
                    }
                }
            ]
        )
    }

    private func applyFilterAndReload() {
        let base: [SavedSet]
        if searchText.isEmpty {
            filteredSets = []
            base = sets
        } else {
            filteredSets = sets.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
            base = filteredSets
        }
        displayedSetCache = sortedSets(base)
        emptyLabel.isHidden = !displayedSetCache.isEmpty
        updateSelectedSetsPanel(animated: false, insertedSetID: nil)
        tableView.reloadData()
    }

    private func deleteSet(id: String) {
        var allSets = SetStore.loadSets()
        if let index = allSets.firstIndex(where: { $0.id == id }) {
            allSets.remove(at: index)
            SetStore.saveSets(allSets)
        }
        reloadData()
    }

    private func showMoveSetSheet(for indexPath: IndexPath) {
        let set = displayedSets()[indexPath.row]
        let folders = FolderStore.loadFolders()
        var actions: [UnifiedModalAction] = [
            UnifiedModalAction(title: "未分類") { [weak self] in
                self?.moveSet(setID: set.id, to: nil)
            }
        ]
        actions.append(contentsOf: folders.map { folder in
            let title = folder.name.trimmingCharacters(in: .whitespacesAndNewlines)
            return UnifiedModalAction(title: title.isEmpty ? "名称未設定" : title) { [weak self] in
                self?.moveSet(setID: set.id, to: folder.id)
            }
        })
        actions.append(UnifiedModalAction(title: "キャンセル", style: .cancel))
        presentUnifiedModal(title: "フォルダー移動", message: nil, actions: actions)
    }

    private func moveSet(setID: String, to folderID: String?) {
        var allSets = SetStore.loadSets()
        guard let index = allSets.firstIndex(where: { $0.id == setID }) else { return }
        allSets[index].folderID = folderID
        SetStore.saveSets(allSets)
        reloadData()
    }

    private func savedWordsFileURL() -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory,
                                                 in: .userDomainMask).first!
        return documents.appendingPathComponent(savedWordsFileName)
    }

    private func loadSavedWords() -> [SavedWord] {
        let fileURL = savedWordsFileURL()
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([SavedWord].self, from: data) {
            if needsWordIDMigration(from: data) {
                saveSavedWords(decoded)
            }
            return decoded
        }

        let legacy = UserDefaults.standard.array(forKey: "WORD") as? [[String: String]] ?? []
        if !legacy.isEmpty {
            let migrated = legacy.map { SavedWord(english: $0["english"] ?? "",
                                                  japanese: $0["japanese"] ?? "",
                                                  illustrationScenario: nil,
                                                  illustrationImageFileName: nil) }
            saveSavedWords(migrated)
            return migrated
        }
        return []
    }

    private func saveSavedWords(_ words: [SavedWord]) {
        let fileURL = savedWordsFileURL()
        guard let data = try? JSONEncoder().encode(words) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

extension SetEditWordsViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        searchText = searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        applyFilterAndReload()
    }
}

extension SetViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        searchText = searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        applyFilterAndReload()
    }
}

final class SetDetailViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let savedWordsFileName = "saved_words.json"
    private enum WordSortOption {
        case setOrder
        case englishAsc
        case englishDesc
        case japaneseAsc
        case japaneseDesc
    }
    private let setID: String
    private var setName: String = ""
    private var words: [SavedWord] = []
    private var filteredWords: [SavedWord] = []
    private var sortOption: WordSortOption = .setOrder
    private var hiddenMode: WordHiddenMode = .none
    private var hideButton: UIBarButtonItem?
    private var revealedWordIDs: Set<String> = []
    private let headerContainer = UIView()
    private let hideToggleButton = UIButton(type: .system)
    private let buttonStack = UIStackView()
    private let flipButton = UIButton(type: .system)
    private let testButton = UIButton(type: .system)
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyLabel = UILabel()
    private let searchController = UISearchController(searchResultsController: nil)
    private var searchText: String = ""
    private var themeObserver: NSObjectProtocol?

    init(setID: String) {
        self.setID = setID
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        configureButtons()
        configureTableView()
        configureEmptyLabel()
        configureSearch()
        configureNavigationItems()
        applyTheme()
        themeObserver = NotificationCenter.default.addObserver(
            forName: ThemeManager.didChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyTheme()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateHeaderLayout()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        applyTheme()
        reloadData()
    }

    private func configureButtons() {
        buttonStack.axis = .horizontal
        buttonStack.spacing = AppSpacing.s(16)
        buttonStack.distribution = .fillEqually
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        flipButton.setTitle("フリップ", for: .normal)
        flipButton.titleLabel?.font = AppFont.jp(size: 16, weight: .bold)
        flipButton.addTarget(self, action: #selector(openFlip), for: .touchUpInside)
        testButton.setTitle("テスト", for: .normal)
        testButton.titleLabel?.font = AppFont.jp(size: 16, weight: .bold)
        testButton.addTarget(self, action: #selector(openTest), for: .touchUpInside)

        buttonStack.addArrangedSubview(flipButton)
        buttonStack.addArrangedSubview(testButton)
        view.addSubview(buttonStack)

        NSLayoutConstraint.activate([
            buttonStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: AppSpacing.s(12)),
            buttonStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AppSpacing.s(16)),
            buttonStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AppSpacing.s(16)),
        ])
    }

    private func configureNavigationItems() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "戻る",
                                                           style: .plain,
                                                           target: self,
                                                           action: #selector(backToSetList))
        let addButton = UIBarButtonItem(title: "単語追加",
                                        style: .plain,
                                        target: self,
                                        action: #selector(openEditWords))
        let editButton = UIBarButtonItem(title: "編集",
                                         style: .plain,
                                         target: self,
                                         action: #selector(toggleEditMode))
        let sortButton = UIBarButtonItem(title: "並び替え",
                                         style: .plain,
                                         target: self,
                                         action: #selector(openSortMenu))
        let renameButton = UIBarButtonItem(title: "名前変更",
                                           style: .plain,
                                           target: self,
                                           action: #selector(renameSet))
        navigationItem.rightBarButtonItems = [addButton, editButton, sortButton, renameButton]
    }

    private func applyTheme() {
        let palette = ThemeManager.palette()
        ThemeManager.applyBackground(to: view)
        ThemeManager.applyNavigationAppearance(to: navigationController)
        ThemeManager.applySearchBar(searchController.searchBar)
        tableView.backgroundColor = .clear
        tableView.separatorColor = palette.border
        emptyLabel.font = AppFont.jp(size: 16)
        emptyLabel.textColor = palette.mutedText
        ThemeManager.stylePrimaryButton(flipButton)
        ThemeManager.stylePrimaryButton(testButton)
    }

    private func configureTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UINib(nibName: "ListTableViewCell", bundle: nil),
                           forCellReuseIdentifier: "cell")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 80
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: buttonStack.bottomAnchor, constant: AppSpacing.s(12)),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func configureSearch() {
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.hidesNavigationBarDuringPresentation = false
        searchController.searchResultsUpdater = self
        searchController.searchBar.placeholder = "単語で検索"
        searchController.searchBar.sizeToFit()
        headerContainer.addSubview(searchController.searchBar)

        tableView.tableHeaderView = headerContainer
        definesPresentationContext = true
    }

    private func updateHeaderLayout() {
        guard let header = tableView.tableHeaderView else { return }
        let width = tableView.bounds.width
        let searchHeight = searchController.searchBar.bounds.height
        let headerHeight = searchHeight
        header.frame = CGRect(x: 0, y: 0, width: width, height: headerHeight)
        searchController.searchBar.frame = CGRect(x: 0, y: 0, width: width, height: searchHeight)
        tableView.tableHeaderView = header
    }

    private func configureEmptyLabel() {
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.text = "このセットには単語がありません。"
        emptyLabel.textAlignment = .center
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.numberOfLines = 0
        view.addSubview(emptyLabel)
        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: AppSpacing.s(20)),
            emptyLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -AppSpacing.s(20)),
        ])
    }

    private func reloadData() {
        let sets = SetStore.loadSets()
        guard let currentSet = sets.first(where: { $0.id == setID }) else {
            navigationController?.popViewController(animated: true)
            return
        }
        setName = currentSet.name
        title = setName
        let allWords = loadSavedWords()
        let wordsByID = Dictionary(uniqueKeysWithValues: allWords.map { ($0.id, $0) })
        words = currentSet.wordIDs.compactMap { wordsByID[$0] }
        applyFilterAndReload()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return displayedWords().count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
            as! ListTableViewCell
        let word = displayedWords()[indexPath.row]
        let isRevealed = revealedWordIDs.contains(word.id)
        cell.configure(word: word, hiddenMode: hiddenMode, isRevealed: isRevealed)
        cell.onFavoriteChanged = { [weak self] isFavorite in
            self?.updateWord(id: word.id, isFavorite: isFavorite)
        }
        cell.onToggleReveal = { [weak self] in
            self?.toggleReveal(for: word.id)
        }
        return cell
    }

    func tableView(_ tableView: UITableView,
                   commit editingStyle: UITableViewCell.EditingStyle,
                   forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let word = displayedWords()[indexPath.row]
            removeWordFromSet(wordID: word.id)
        }
    }

    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath)
    -> UISwipeActionsConfiguration? {
        let move = UIContextualAction(style: .normal, title: "移動") { [weak self] _, _, completion in
            self?.showMoveWordSheet(for: indexPath)
            completion(true)
        }
        move.backgroundColor = .systemBlue
        let delete = UIContextualAction(style: .destructive, title: "削除") { [weak self] _, _, completion in
            if let word = self?.displayedWords()[indexPath.row] {
                self?.removeWordFromSet(wordID: word.id)
            }
            completion(true)
        }
        return UISwipeActionsConfiguration(actions: [delete, move])
    }

    @objc private func openFlip() {
        LastStudyStore.save(setID: setID, setName: setName)
        let controller = FlipViewController()
        controller.presetWords = words
        controller.title = "\(setName) フリップ"
        navigationController?.pushViewController(controller, animated: true)
    }

    @objc private func openTest() {
        LastStudyStore.save(setID: setID, setName: setName)
        let controller = TestViewController()
        controller.presetWords = words
        controller.title = "\(setName) テスト"
        navigationController?.pushViewController(controller, animated: true)
    }

    @objc private func backToSetList() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func toggleEditMode() {
        let shouldEdit = !tableView.isEditing
        tableView.setEditing(shouldEdit, animated: true)
        if let editButton = navigationItem.rightBarButtonItems?.first(where: { $0.title == "編集" || $0.title == "完了" }) {
            editButton.title = shouldEdit ? "完了" : "編集"
        }
    }

    @objc private func openEditWords() {
        let controller = SetEditWordsViewController(setID: setID)
        navigationController?.pushViewController(controller, animated: true)
    }

    @objc private func renameSet() {
        let nameField = UITextField()
        nameField.borderStyle = .roundedRect
        nameField.text = setName
        nameField.placeholder = "セット名"
        presentUnifiedModal(
            title: "名前変更",
            message: nil,
            contentView: nameField,
            actions: [
                UnifiedModalAction(title: "キャンセル", style: .cancel),
                UnifiedModalAction(title: "保存") { [weak self] in
                    guard let self else { return }
                    let name = nameField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    guard !name.isEmpty else { return }
                    var sets = SetStore.loadSets()
                    if let index = sets.firstIndex(where: { $0.id == self.setID }) {
                        sets[index].name = name
                        SetStore.saveSets(sets)
                        self.setName = name
                        self.title = name
                    }
                }
            ]
        )
    }

    @objc private func openSortMenu() {
        let actions: [UnifiedModalAction] = [
            UnifiedModalAction(title: "セット順") { [weak self] in
                self?.sortOption = .setOrder
                self?.applyFilterAndReload()
            },
            UnifiedModalAction(title: "英語 A→Z") { [weak self] in
                self?.sortOption = .englishAsc
                self?.applyFilterAndReload()
            },
            UnifiedModalAction(title: "英語 Z→A") { [weak self] in
                self?.sortOption = .englishDesc
                self?.applyFilterAndReload()
            },
            UnifiedModalAction(title: "日本語 あ→ん") { [weak self] in
                self?.sortOption = .japaneseAsc
                self?.applyFilterAndReload()
            },
            UnifiedModalAction(title: "日本語 ん→あ") { [weak self] in
                self?.sortOption = .japaneseDesc
                self?.applyFilterAndReload()
            },
            UnifiedModalAction(title: "キャンセル", style: .cancel)
        ]
        presentUnifiedModal(title: "並び替え", message: nil, actions: actions)
    }

    private func updateHiddenButtonTitle() {
        let title = hiddenMode == .none ? "隠す" : "表示"
        hideToggleButton.setTitle(title, for: .normal)
    }

    @objc private func toggleHiddenMode() {
        if hiddenMode != .none {
            hiddenMode = .none
            revealedWordIDs.removeAll()
            updateHiddenButtonTitle()
            tableView.reloadData()
            return
        }

        presentUnifiedModal(
            title: "隠す項目",
            message: nil,
            actions: [
                UnifiedModalAction(title: "英語を隠す") { [weak self] in
                    self?.hiddenMode = .english
                    self?.revealedWordIDs.removeAll()
                    self?.updateHiddenButtonTitle()
                    self?.tableView.reloadData()
                },
                UnifiedModalAction(title: "日本語を隠す") { [weak self] in
                    self?.hiddenMode = .japanese
                    self?.revealedWordIDs.removeAll()
                    self?.updateHiddenButtonTitle()
                    self?.tableView.reloadData()
                },
                UnifiedModalAction(title: "キャンセル", style: .cancel)
            ]
        )
    }

    private func displayedWords() -> [SavedWord] {
        let base: [SavedWord]
        if searchText.isEmpty {
            base = words
        } else {
            base = filteredWords
        }
        return sortedWords(base)
    }

    private func sortedWords(_ input: [SavedWord]) -> [SavedWord] {
        switch sortOption {
        case .setOrder:
            return input
        case .englishAsc:
            return input.sorted { $0.english.localizedCaseInsensitiveCompare($1.english) == .orderedAscending }
        case .englishDesc:
            return input.sorted { $0.english.localizedCaseInsensitiveCompare($1.english) == .orderedDescending }
        case .japaneseAsc:
            return input.sorted { $0.japanese.localizedCaseInsensitiveCompare($1.japanese) == .orderedAscending }
        case .japaneseDesc:
            return input.sorted { $0.japanese.localizedCaseInsensitiveCompare($1.japanese) == .orderedDescending }
        }
    }

    private func applyFilterAndReload() {
        if searchText.isEmpty {
            filteredWords = []
        } else {
            filteredWords = words.filter {
                $0.english.localizedCaseInsensitiveContains(searchText)
                    || $0.japanese.localizedCaseInsensitiveContains(searchText)
            }
        }
        let displayed = displayedWords()
        emptyLabel.isHidden = !displayed.isEmpty
        flipButton.isEnabled = !displayed.isEmpty
        testButton.isEnabled = !displayed.isEmpty
        tableView.reloadData()
    }

    private func removeWordFromSet(wordID: String) {
        var sets = SetStore.loadSets()
        guard let index = sets.firstIndex(where: { $0.id == setID }) else { return }
        sets[index].wordIDs.removeAll { $0 == wordID }
        SetStore.saveSets(sets)
        reloadData()
    }

    private func showMoveWordSheet(for indexPath: IndexPath) {
        let word = displayedWords()[indexPath.row]
        let sets = SetStore.loadSets()
        let targets = sets.filter { $0.id != setID }
        guard !targets.isEmpty else {
            presentUnifiedModal(
                title: "移動先がありません",
                message: "他のセットを作成してください。",
                actions: [UnifiedModalAction(title: "OK")]
            )
            return
        }
        var actions = targets.map { target in
            UnifiedModalAction(title: target.name) { [weak self] in
                self?.moveWord(wordID: word.id, to: target.id)
            }
        }
        actions.append(UnifiedModalAction(title: "キャンセル", style: .cancel))
        presentUnifiedModal(title: "移動先を選択", message: nil, actions: actions)
    }

    private func moveWord(wordID: String, to targetSetID: String) {
        var sets = SetStore.loadSets()
        guard let sourceIndex = sets.firstIndex(where: { $0.id == setID }),
              let targetIndex = sets.firstIndex(where: { $0.id == targetSetID }) else { return }
        sets[sourceIndex].wordIDs.removeAll { $0 == wordID }
        if !sets[targetIndex].wordIDs.contains(wordID) {
            sets[targetIndex].wordIDs.append(wordID)
        }
        SetStore.saveSets(sets)
        reloadData()
    }

    private func savedWordsFileURL() -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory,
                                                 in: .userDomainMask).first!
        return documents.appendingPathComponent(savedWordsFileName)
    }

    private func loadSavedWords() -> [SavedWord] {
        let fileURL = savedWordsFileURL()
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([SavedWord].self, from: data) {
            if needsWordIDMigration(from: data) {
                saveSavedWords(decoded)
            }
            return decoded
        }

        let legacy = UserDefaults.standard.array(forKey: "WORD") as? [[String: String]] ?? []
        if !legacy.isEmpty {
            let migrated = legacy.map { SavedWord(english: $0["english"] ?? "",
                                                  japanese: $0["japanese"] ?? "",
                                                  illustrationScenario: nil,
                                                  illustrationImageFileName: nil) }
            saveSavedWords(migrated)
            return migrated
        }
        return []
    }

    private func saveSavedWords(_ words: [SavedWord]) {
        let fileURL = savedWordsFileURL()
        guard let data = try? JSONEncoder().encode(words) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private func updateWord(id: String, isFavorite: Bool? = nil, importanceLevel: Int? = nil) {
        var allWords = loadSavedWords()
        guard let index = allWords.firstIndex(where: { $0.id == id }) else { return }
        var word = allWords[index]
        if let isFavorite {
            word.isFavorite = isFavorite
        }
        if let importanceLevel {
            word.importanceLevel = importanceLevel
        }
        allWords[index] = word
        saveSavedWords(allWords)
        if let localIndex = words.firstIndex(where: { $0.id == id }) {
            words[localIndex] = word
        }
    }

    private func presentImportancePicker(for word: SavedWord) {
        var actions: [UnifiedModalAction] = (1...5).map { level in
            UnifiedModalAction(title: "Lv\(level)") { [weak self] in
                self?.updateWord(id: word.id, importanceLevel: level)
                if let indexPath = self?.indexPathForWord(id: word.id),
                   let cell = self?.tableView.cellForRow(at: indexPath) as? ListTableViewCell {
                    cell.updateImportance(level: level)
                }
            }
        }
        actions.append(UnifiedModalAction(title: "キャンセル", style: .cancel))
        presentUnifiedModal(title: "重要度", message: nil, actions: actions)
    }

    private func toggleReveal(for id: String) {
        guard hiddenMode != .none else { return }
        if revealedWordIDs.contains(id) {
            revealedWordIDs.remove(id)
        } else {
            revealedWordIDs.insert(id)
        }
        if let indexPath = indexPathForWord(id: id) {
            tableView.reloadRows(at: [indexPath], with: .none)
        }
    }

    private func indexPathForWord(id: String) -> IndexPath? {
        let current = displayedWords()
        guard let row = current.firstIndex(where: { $0.id == id }) else { return nil }
        return IndexPath(row: row, section: 0)
    }

    deinit {
        if let observer = themeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

extension SetDetailViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        searchText = searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        applyFilterAndReload()
    }
}

final class SetCreateViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let savedWordsFileName = "saved_words.json"
    private let folderID: String?
    private var words: [SavedWord] = []
    private var selectedWordIDs: Set<String> = []
    private let nameTextField = UITextField()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyLabel = UILabel()
    private let saveButton = UIButton(type: .system)

    init(folderID: String?) {
        self.folderID = folderID
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        folderID = nil
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "セット追加"
        view.backgroundColor = .systemBackground
        configureNavigationItems()
        configureNameField()
        configureTableView()
        configureEmptyLabel()
        loadWords()
    }

    private func configureNavigationItems() {
        styleSaveButton()
        saveButton.addTarget(self, action: #selector(saveSet), for: .touchUpInside)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: saveButton)
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "キャンセル",
                                                           style: .plain,
                                                           target: self,
                                                           action: #selector(cancel))
    }

    private func styleSaveButton() {
        saveButton.titleLabel?.font = AppFont.jp(size: 14, weight: .bold)
        saveButton.setTitle("保存", for: .normal)
        ThemeManager.stylePrimaryButton(saveButton)
    }

    private func configureNameField() {
        nameTextField.translatesAutoresizingMaskIntoConstraints = false
        nameTextField.borderStyle = .roundedRect
        nameTextField.placeholder = "セット名"
        view.addSubview(nameTextField)

        NSLayoutConstraint.activate([
            nameTextField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: AppSpacing.s(12)),
            nameTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AppSpacing.s(16)),
            nameTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AppSpacing.s(16)),
            nameTextField.heightAnchor.constraint(equalToConstant: 40),
        ])
    }

    private func configureTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsMultipleSelection = true
        tableView.register(UINib(nibName: "ListTableViewCell", bundle: nil),
                           forCellReuseIdentifier: "cell")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 80
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: nameTextField.bottomAnchor, constant: AppSpacing.s(12)),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func configureEmptyLabel() {
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.text = "単語がありません。\n先に単語を追加してください。"
        emptyLabel.textAlignment = .center
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.numberOfLines = 0
        view.addSubview(emptyLabel)
        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: AppSpacing.s(20)),
            emptyLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -AppSpacing.s(20)),
        ])
    }

    private func loadWords() {
        words = loadSavedWords()
        emptyLabel.isHidden = !words.isEmpty
        saveButton.isEnabled = !words.isEmpty
        saveButton.setNeedsUpdateConfiguration()
        tableView.reloadData()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return words.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
            as! ListTableViewCell
        let word = words[indexPath.row]
        cell.englishLabel.text = word.english
        cell.japaneseLabel.text = word.japanese
        cell.applyHiddenMode(.none, isRevealed: false)
        cell.accessoryType = selectedWordIDs.contains(word.id) ? .checkmark : .none
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let word = words[indexPath.row]
        if selectedWordIDs.contains(word.id) {
            selectedWordIDs.remove(word.id)
        } else {
            selectedWordIDs.insert(word.id)
        }
        tableView.deselectRow(at: indexPath, animated: true)
        tableView.reloadRows(at: [indexPath], with: .none)
    }

    @objc private func saveSet() {
        let name = nameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !name.isEmpty else {
            showAlert(title: "入力エラー", message: "セット名を入力してください。")
            return
        }
        guard !selectedWordIDs.isEmpty else {
            showAlert(title: "選択エラー", message: "単語を1つ以上選択してください。")
            return
        }
        var sets = SetStore.loadSets()
        let orderedIDs = words.filter { selectedWordIDs.contains($0.id) }.map { $0.id }
        let newSet = SavedSet(name: name, wordIDs: orderedIDs, folderID: folderID)
        sets.append(newSet)
        SetStore.saveSets(sets)
        navigationController?.popViewController(animated: true)
    }

    @objc private func cancel() {
        navigationController?.popViewController(animated: true)
    }

    private func showAlert(title: String, message: String) {
        presentUnifiedModal(title: title,
                            message: message,
                            actions: [UnifiedModalAction(title: "OK")])
    }

    private func savedWordsFileURL() -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory,
                                                 in: .userDomainMask).first!
        return documents.appendingPathComponent(savedWordsFileName)
    }

    private func loadSavedWords() -> [SavedWord] {
        let fileURL = savedWordsFileURL()
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([SavedWord].self, from: data) {
            if needsWordIDMigration(from: data) {
                saveSavedWords(decoded)
            }
            return decoded
        }

        let legacy = UserDefaults.standard.array(forKey: "WORD") as? [[String: String]] ?? []
        if !legacy.isEmpty {
            let migrated = legacy.map { SavedWord(english: $0["english"] ?? "",
                                                  japanese: $0["japanese"] ?? "",
                                                  illustrationScenario: nil,
                                                  illustrationImageFileName: nil) }
            saveSavedWords(migrated)
            return migrated
        }
        return []
    }

    private func saveSavedWords(_ words: [SavedWord]) {
        let fileURL = savedWordsFileURL()
        guard let data = try? JSONEncoder().encode(words) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

final class SetEditWordsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let savedWordsFileName = "saved_words.json"
    private enum WordSortOption {
        case created
        case englishAsc
        case englishDesc
        case japaneseAsc
        case japaneseDesc
    }
    private let setID: String
    private var words: [SavedWord] = []
    private var filteredWords: [SavedWord] = []
    private var selectedWordIDs: Set<String> = []
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyLabel = UILabel()
    private let searchController = UISearchController(searchResultsController: nil)
    private var searchText: String = ""
    private var sortOption: WordSortOption = .created

    init(setID: String) {
        self.setID = setID
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "単語を編集"
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "保存",
                                                            style: .done,
                                                            target: self,
                                                            action: #selector(saveChanges))
        let backItem = UIBarButtonItem(title: "戻る",
                                       style: .plain,
                                       target: self,
                                       action: #selector(goBack))
        let sortItem = UIBarButtonItem(title: "並び替え",
                                       style: .plain,
                                       target: self,
                                       action: #selector(openSortMenu))
        navigationItem.leftBarButtonItems = [backItem, sortItem]
        let pixelAttrs: [NSAttributedString.Key: Any] = [
            .font: AppFont.jp(size: 14, weight: .bold)
        ]
        backItem.setTitleTextAttributes(pixelAttrs, for: .normal)
        backItem.setTitleTextAttributes(pixelAttrs, for: .highlighted)
        sortItem.setTitleTextAttributes(pixelAttrs, for: .normal)
        sortItem.setTitleTextAttributes(pixelAttrs, for: .highlighted)
        navigationItem.rightBarButtonItem?.setTitleTextAttributes(pixelAttrs, for: .normal)
        navigationItem.rightBarButtonItem?.setTitleTextAttributes(pixelAttrs, for: .highlighted)
        configureTableView()
        configureEmptyLabel()
        configureSearch()
        loadData()
    }

    @objc private func goBack() {
        navigationController?.popViewController(animated: true)
    }

    private func configureTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UINib(nibName: "ListTableViewCell", bundle: nil),
                           forCellReuseIdentifier: "cell")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 80
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func configureSearch() {
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.hidesNavigationBarDuringPresentation = false
        searchController.searchResultsUpdater = self
        searchController.searchBar.placeholder = "単語で検索"
        searchController.searchBar.sizeToFit()
        tableView.tableHeaderView = searchController.searchBar
        searchController.searchBar.frame = CGRect(
            x: 0,
            y: 0,
            width: tableView.bounds.width,
            height: searchController.searchBar.bounds.height
        )
        definesPresentationContext = true
    }

    private func configureEmptyLabel() {
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.text = "単語がありません。\n先に単語を追加してください。"
        emptyLabel.textAlignment = .center
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.numberOfLines = 0
        view.addSubview(emptyLabel)
        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: AppSpacing.s(20)),
            emptyLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -AppSpacing.s(20)),
        ])
    }

    private func loadData() {
        words = loadSavedWords()
        let sets = SetStore.loadSets()
        if let currentSet = sets.first(where: { $0.id == setID }) {
            selectedWordIDs = Set(currentSet.wordIDs)
        }
        applyFilterAndReload()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return displayedWords().count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
            as! ListTableViewCell
        let word = displayedWords()[indexPath.row]
        cell.englishLabel.text = word.english
        cell.japaneseLabel.text = word.japanese
        cell.applyHiddenMode(.none, isRevealed: false)
        cell.accessoryType = selectedWordIDs.contains(word.id) ? .checkmark : .none
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let word = words[indexPath.row]
        if selectedWordIDs.contains(word.id) {
            selectedWordIDs.remove(word.id)
        } else {
            selectedWordIDs.insert(word.id)
        }
        tableView.deselectRow(at: indexPath, animated: true)
        tableView.reloadRows(at: [indexPath], with: .none)
    }

    @objc private func openSortMenu() {
        let actions: [UnifiedModalAction] = [
            UnifiedModalAction(title: "作成順") { [weak self] in
                self?.sortOption = .created
                self?.applyFilterAndReload()
            },
            UnifiedModalAction(title: "英語 A→Z") { [weak self] in
                self?.sortOption = .englishAsc
                self?.applyFilterAndReload()
            },
            UnifiedModalAction(title: "英語 Z→A") { [weak self] in
                self?.sortOption = .englishDesc
                self?.applyFilterAndReload()
            },
            UnifiedModalAction(title: "日本語 あ→ん") { [weak self] in
                self?.sortOption = .japaneseAsc
                self?.applyFilterAndReload()
            },
            UnifiedModalAction(title: "日本語 ん→あ") { [weak self] in
                self?.sortOption = .japaneseDesc
                self?.applyFilterAndReload()
            },
            UnifiedModalAction(title: "キャンセル", style: .cancel)
        ]
        presentUnifiedModal(title: "並び替え", message: nil, actions: actions)
    }

    private func displayedWords() -> [SavedWord] {
        let base: [SavedWord]
        if searchText.isEmpty {
            base = words
        } else {
            base = filteredWords
        }
        return sortedWords(base)
    }

    private func sortedWords(_ input: [SavedWord]) -> [SavedWord] {
        switch sortOption {
        case .created:
            return input
        case .englishAsc:
            return input.sorted { $0.english.localizedCaseInsensitiveCompare($1.english) == .orderedAscending }
        case .englishDesc:
            return input.sorted { $0.english.localizedCaseInsensitiveCompare($1.english) == .orderedDescending }
        case .japaneseAsc:
            return input.sorted { $0.japanese.localizedCaseInsensitiveCompare($1.japanese) == .orderedAscending }
        case .japaneseDesc:
            return input.sorted { $0.japanese.localizedCaseInsensitiveCompare($1.japanese) == .orderedDescending }
        }
    }

    private func applyFilterAndReload() {
        if searchText.isEmpty {
            filteredWords = []
        } else {
            filteredWords = words.filter {
                $0.english.localizedCaseInsensitiveContains(searchText)
                    || $0.japanese.localizedCaseInsensitiveContains(searchText)
            }
        }
        emptyLabel.isHidden = !displayedWords().isEmpty
        navigationItem.rightBarButtonItem?.isEnabled = !words.isEmpty
        tableView.reloadData()
    }

    @objc private func saveChanges() {
        guard !selectedWordIDs.isEmpty else {
            presentUnifiedModal(
                title: "選択エラー",
                message: "単語を1つ以上選択してください。",
                actions: [UnifiedModalAction(title: "OK")]
            )
            return
        }
        var sets = SetStore.loadSets()
        guard let index = sets.firstIndex(where: { $0.id == setID }) else { return }
        let orderedIDs = words.filter { selectedWordIDs.contains($0.id) }.map { $0.id }
        sets[index].wordIDs = orderedIDs
        SetStore.saveSets(sets)
        navigationController?.popViewController(animated: true)
    }

    private func savedWordsFileURL() -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory,
                                                 in: .userDomainMask).first!
        return documents.appendingPathComponent(savedWordsFileName)
    }

    private func loadSavedWords() -> [SavedWord] {
        let fileURL = savedWordsFileURL()
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([SavedWord].self, from: data) {
            if needsWordIDMigration(from: data) {
                saveSavedWords(decoded)
            }
            return decoded
        }

        let legacy = UserDefaults.standard.array(forKey: "WORD") as? [[String: String]] ?? []
        if !legacy.isEmpty {
            let migrated = legacy.map { SavedWord(english: $0["english"] ?? "",
                                                  japanese: $0["japanese"] ?? "",
                                                  illustrationScenario: nil,
                                                  illustrationImageFileName: nil) }
            saveSavedWords(migrated)
            return migrated
        }
        return []
    }

    private func saveSavedWords(_ words: [SavedWord]) {
        let fileURL = savedWordsFileURL()
        guard let data = try? JSONEncoder().encode(words) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
