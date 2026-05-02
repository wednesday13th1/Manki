//
//  WhichViewController.swift
//  manki
//
//  Created by 井上　希稟 on 2026/01/28.
//

import UIKit

class WhichViewController: UIViewController {

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private var themeObserver: NSObjectProtocol?
    private var testMenuOverlay: UIControl?
    private var testMenuContainer: UIView?
    private var testMenuTitleLabel: UILabel?
    private var testMenuButtons: [UIButton] = []

    private lazy var testButton: UIButton = makeButton(
        title: "テスト",
        action: #selector(openTest)
    )

    private lazy var flipButton: UIButton = makeButton(
        title: "フリップ",
        action: #selector(openFlip)
    )

    private lazy var redSheetButton: UIButton = makeButton(
        title: "赤シート",
        action: #selector(openRedSheet)
    )

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        applyTheme()
        themeObserver = NotificationCenter.default.addObserver(
            forName: ThemeManager.didChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyTheme()
        }
    }

    private func setupUI() {
        titleLabel.text = "Study Mode"
        titleLabel.textAlignment = .center
        subtitleLabel.text = ""
        subtitleLabel.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, testButton, flipButton, redSheetButton])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = AppSpacing.s(14)
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        let centerY = stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        centerY.priority = .defaultLow
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            centerY,
            stack.topAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.topAnchor, constant: AppSpacing.s(16)),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -AppSpacing.s(16)),
            stack.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.7)
        ])
    }

    private func makeButton(title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = AppFont.jp(size: 18, weight: .bold)
        let preferredHeight = button.heightAnchor.constraint(equalToConstant: 48)
        preferredHeight.priority = .defaultHigh
        preferredHeight.isActive = true
        let minHeight = button.heightAnchor.constraint(greaterThanOrEqualToConstant: 40)
        minHeight.priority = .defaultLow
        minHeight.isActive = true
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    @objc private func openTest() {
        showTestMenuModal()
    }

    @objc private func openFlip() {
        let controller = FlipViewController()
        navigationController?.pushViewController(controller, animated: true)
    }

    @objc private func openRedSheet() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let listVC = storyboard.instantiateViewController(withIdentifier: "ListTableViewController")
                as? ListTableViewController else {
            return
        }
        listVC.startEditing = false
        listVC.hideTestAndAdd = true
        listVC.showHideButton = true
        navigationController?.pushViewController(listVC, animated: true)
    }

    private func applyTheme() {
        let palette = ThemeManager.palette()
        ThemeManager.applyBackground(to: view)
        titleLabel.font = AppFont.title(size: 20)
        titleLabel.textColor = palette.text
        subtitleLabel.font = AppFont.en(size: 22)
        subtitleLabel.textColor = palette.mutedText
        ThemeManager.stylePrimaryButton(testButton)
        ThemeManager.styleSecondaryButton(flipButton)
        ThemeManager.styleSecondaryButton(redSheetButton)
        updateTestMenuTheme()
    }

    deinit {
        if let observer = themeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func showTestMenuModal() {
        guard testMenuOverlay == nil else { return }
        let overlay = UIControl()
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.addTarget(self, action: #selector(dismissTestMenuModal), for: .touchUpInside)
        overlay.accessibilityViewIsModal = true

        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "テスト"
        titleLabel.textAlignment = .center

        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = AppSpacing.s(8)

        let startButton = makeMenuButton(title: "テスト開始", action: #selector(handleTestStart))
        let resultButton = makeMenuButton(title: "結果を見る", action: #selector(handleTestResults))
        let weakButton = makeMenuButton(title: "苦手単語", action: #selector(handleWeakWords))
        let cancelButton = makeMenuButton(title: "キャンセル", action: #selector(dismissTestMenuModal))

        [startButton, resultButton, weakButton, cancelButton].forEach { button in
            stack.addArrangedSubview(button)
            let preferredHeight = button.heightAnchor.constraint(equalToConstant: 40)
            preferredHeight.priority = .defaultHigh
            preferredHeight.isActive = true
            let minHeight = button.heightAnchor.constraint(greaterThanOrEqualToConstant: 34)
            minHeight.priority = .defaultLow
            minHeight.isActive = true
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

            container.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            container.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            container.widthAnchor.constraint(equalToConstant: 260),
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

        testMenuOverlay = overlay
        testMenuContainer = container
        testMenuTitleLabel = titleLabel
        testMenuButtons = [startButton, resultButton, weakButton, cancelButton]
        updateTestMenuTheme()

        overlay.alpha = 0
        container.alpha = 0
        container.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseOut]) {
            overlay.alpha = 1
            container.alpha = 1
            container.transform = .identity
        }
    }

    @objc private func dismissTestMenuModal() {
        guard let overlay = testMenuOverlay, let container = testMenuContainer else { return }
        UIView.animate(withDuration: 0.15, delay: 0, options: [.curveEaseIn]) {
            overlay.alpha = 0
            container.alpha = 0
            container.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        } completion: { [weak self] _ in
            overlay.removeFromSuperview()
            self?.testMenuOverlay = nil
            self?.testMenuContainer = nil
            self?.testMenuTitleLabel = nil
            self?.testMenuButtons = []
        }
    }

    @objc private func handleTestStart() {
        dismissTestMenuModal()
        let controller = TestViewController()
        navigationController?.pushViewController(controller, animated: true)
    }

    @objc private func handleTestResults() {
        dismissTestMenuModal()
        let controller = ResultViewController()
        navigationController?.pushViewController(controller, animated: true)
    }

    @objc private func handleWeakWords() {
        dismissTestMenuModal()
        let weakIDs = loadWeakWordIDs()
        guard !weakIDs.isEmpty else {
            presentUnifiedModal(
                title: "苦手単語",
                message: "苦手単語がありません。",
                actions: [UnifiedModalAction(title: "OK")]
            )
            return
        }
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let listVC = storyboard.instantiateViewController(withIdentifier: "ListTableViewController")
                as? ListTableViewController else {
            return
        }
        listVC.title = "苦手単語"
        listVC.startEditing = false
        listVC.hideTestAndAdd = true
        listVC.showHideButton = true
        listVC.filterWordIDs = weakIDs
        navigationController?.pushViewController(listVC, animated: true)
    }

    private func makeMenuButton(title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(title, for: .normal)
        button.addTarget(self, action: action, for: .touchUpInside)
        button.titleLabel?.font = AppFont.jp(size: 16, weight: .bold)
        if var configuration = button.configuration {
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
            button.configuration = configuration
        } else {
            button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        }
        button.layer.borderWidth = 2
        button.layer.cornerRadius = 0
        button.layer.masksToBounds = true
        return button
    }

    private func updateTestMenuTheme() {
        guard let overlay = testMenuOverlay,
              let container = testMenuContainer,
              let titleLabel = testMenuTitleLabel else { return }
        let palette = ThemeManager.palette()
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        container.backgroundColor = palette.surface
        container.layer.borderWidth = 2
        container.layer.borderColor = palette.border.cgColor
        titleLabel.font = AppFont.jp(size: 18, weight: .bold)
        titleLabel.textColor = palette.text
        testMenuButtons.forEach { button in
            button.backgroundColor = palette.surfaceAlt
            button.layer.borderColor = palette.border.cgColor
            button.setTitleColor(palette.text, for: .normal)
        }
    }

    private func resultsFileURL() -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory,
                                                 in: .userDomainMask).first!
        return documents.appendingPathComponent("results.json")
    }

    private func loadWeakWordIDs() -> Set<String> {
        let url = resultsFileURL()
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(WeakResultsDatabase.self, from: data) else {
            return []
        }
        var weakIDs: Set<String> = []
        for session in decoded.sessions {
            if session.reason == "flip" || session.modeLabel == "フリップ" {
                continue
            }
            for question in session.questions {
                guard let wordId = question.wordId, !wordId.isEmpty else { continue }
                if question.type == "flip" { continue }
                if question.correct == false {
                    weakIDs.insert(wordId)
                }
            }
        }
        return weakIDs
    }

}

private struct WeakResultsDatabase: Codable {
    let sessions: [WeakSessionResult]
}

private struct WeakSessionResult: Codable {
    let reason: String?
    let modeLabel: String?
    let questions: [WeakSessionQuestion]

    enum CodingKeys: String, CodingKey {
        case reason
        case modeLabel
        case questions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        reason = try container.decodeIfPresent(String.self, forKey: .reason)
        modeLabel = try container.decodeIfPresent(String.self, forKey: .modeLabel)
        questions = try container.decodeIfPresent([WeakSessionQuestion].self, forKey: .questions) ?? []
    }
}

private struct WeakSessionQuestion: Codable {
    let type: String?
    let wordId: String?
    let correct: Bool

    enum CodingKeys: String, CodingKey {
        case type
        case wordId
        case correct
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        wordId = try container.decodeIfPresent(String.self, forKey: .wordId)
        correct = try container.decodeIfPresent(Bool.self, forKey: .correct) ?? false
    }
}
