import UIKit

final class KeywordDetailViewController: BaseViewController {
    private let keyword: MankiKeyword
    private let onAddWordCard: () -> Void
    private let onAddWeakWord: () -> Void
    private let onPracticeOnly: () -> Void

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private let wordLabel = UILabel()
    private let meaningLabel = UILabel()
    private let difficultyBadge = UILabel()
    private let reasonLabel = UILabel()
    private let exampleTitleLabel = UILabel()
    private let exampleLabel = UILabel()
    private let locationLabel = UILabel()
    private let addCardButton = UIButton(type: .system)
    private let addWeakButton = UIButton(type: .system)
    private let practiceButton = UIButton(type: .system)

    init(keyword: MankiKeyword,
         onAddWordCard: @escaping () -> Void,
         onAddWeakWord: @escaping () -> Void,
         onPracticeOnly: @escaping () -> Void) {
        self.keyword = keyword
        self.onAddWordCard = onAddWordCard
        self.onAddWeakWord = onAddWeakWord
        self.onPracticeOnly = onPracticeOnly
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Keyword"
        configureUI()
        applyContent()
    }

    override func applyBaseTheme() {
        super.applyBaseTheme()
        let palette = ThemeManager.palette()
        [wordLabel, meaningLabel, reasonLabel, exampleTitleLabel, exampleLabel, locationLabel].forEach {
            $0.textColor = palette.text
        }
        meaningLabel.textColor = palette.mutedText
        reasonLabel.textColor = palette.mutedText
        locationLabel.textColor = palette.mutedText
        ThemeManager.stylePrimaryButton(addCardButton)
        ThemeManager.styleSecondaryButton(addWeakButton)
        ThemeManager.styleSecondaryButton(practiceButton)
        difficultyBadge.layer.borderColor = palette.border.cgColor
        difficultyBadge.textColor = palette.text
        difficultyBadge.backgroundColor = palette.surfaceAlt.withAlphaComponent(0.9)
    }

    private func configureUI() {
        [scrollView, stackView, wordLabel, meaningLabel, difficultyBadge, reasonLabel, exampleTitleLabel, exampleLabel, locationLabel, addCardButton, addWeakButton, practiceButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        stackView.axis = .vertical
        stackView.spacing = AppSpacing.s(12)

        difficultyBadge.layer.cornerRadius = 12
        difficultyBadge.layer.borderWidth = 1.5
        difficultyBadge.layer.masksToBounds = true
        difficultyBadge.textAlignment = .center
        difficultyBadge.font = AppFont.jp(size: 12, weight: .bold)

        exampleLabel.numberOfLines = 0
        reasonLabel.numberOfLines = 0
        locationLabel.numberOfLines = 0

        addCardButton.setTitle("単語カードに追加", for: .normal)
        addWeakButton.setTitle("苦手単語に追加", for: .normal)
        practiceButton.setTitle("この単語だけ練習", for: .normal)

        addCardButton.addTarget(self, action: #selector(addCardTapped), for: .touchUpInside)
        addWeakButton.addTarget(self, action: #selector(addWeakTapped), for: .touchUpInside)
        practiceButton.addTarget(self, action: #selector(practiceTapped), for: .touchUpInside)

        let buttonStack = UIStackView(arrangedSubviews: [addCardButton, addWeakButton, practiceButton])
        buttonStack.axis = .vertical
        buttonStack.spacing = AppSpacing.s(10)
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        scrollView.addSubview(stackView)

        [wordLabel, meaningLabel, difficultyBadge, reasonLabel, exampleTitleLabel, exampleLabel, locationLabel, buttonStack].forEach {
            stackView.addArrangedSubview($0)
        }

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

            difficultyBadge.heightAnchor.constraint(greaterThanOrEqualToConstant: 28)
        ])
    }

    private func applyContent() {
        wordLabel.applyMankiTextStyle(.screenTitle, color: ThemeManager.palette().text, numberOfLines: 0)
        meaningLabel.applyMankiTextStyle(.body, color: ThemeManager.palette().mutedText, numberOfLines: 0)
        reasonLabel.applyMankiTextStyle(.caption, color: ThemeManager.palette().mutedText, numberOfLines: 0)
        exampleTitleLabel.applyMankiTextStyle(.sectionTitle, color: ThemeManager.palette().text, numberOfLines: 1)
        exampleLabel.applyMankiTextStyle(.body, color: ThemeManager.palette().text, numberOfLines: 0)
        locationLabel.applyMankiTextStyle(.caption, color: ThemeManager.palette().mutedText, numberOfLines: 0)

        wordLabel.text = keyword.word
        meaningLabel.text = keyword.meaning
        difficultyBadge.text = " \(keyword.difficulty.uppercased()) "
        reasonLabel.text = keyword.reason ?? "歌詞の中で学習価値がある単語です。"
        exampleTitleLabel.text = "Example"
        exampleLabel.text = keyword.example
        locationLabel.text = locationText()
    }

    private func locationText() -> String {
        let linePart = keyword.lyricLineIndex.map { "line \($0 + 1)" }
        let timePart = keyword.startTime.map { "time \(formattedTime($0))" }
        let parts = [linePart, timePart].compactMap { $0 }
        if parts.isEmpty {
            return "位置情報なし"
        }
        return parts.joined(separator: " / ")
    }

    private func formattedTime(_ time: TimeInterval) -> String {
        let total = Int(time.rounded(.down))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    @objc private func addCardTapped() {
        onAddWordCard()
    }

    @objc private func addWeakTapped() {
        onAddWeakWord()
    }

    @objc private func practiceTapped() {
        onPracticeOnly()
    }
}
