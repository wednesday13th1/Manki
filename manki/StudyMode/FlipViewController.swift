//
//  FlipViewController.swift　.. Flip card
//  manki
//
//  Created by 井上　希稟 on 2026/01/17.
//

//
import UIKit
import AVFoundation

class FlipViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource {

    private let savedWordsFileName = "saved_words.json"
    private let resultsFileName = "results.json"
    var presetWords: [SavedWord]?
    private var words: [SavedWord] = []
    private var currentIndex = 0
    private var isFlipped = false
    private var sessionStartTime: Date?
    private var hasRecordedSession = false
    private var viewedWordIDs: [String] = []
    private var viewedWordIDSet: Set<String> = []

    private let timerStack = UIStackView()
    private let timerTitleLabel = UILabel()
    private let timeTextField = UITextField()
    private let timerStartButton = UIButton(type: .system)
    private let remainingTimeLabel = UILabel()
    private let timePicker = UIPickerView()
    private let timeOptionsSec = Array(stride(from: 0, through: 1800, by: 30))
    private var selectedTimeSeconds = 0
    private var timer: Timer?
    private var endTime: Date?

    private var timeUpOverlay: UIControl?
    private var timeUpContainer: UIView?
    private var timeUpTitleLabel: UILabel?
    private var timeUpMessageLabel: UILabel?
    private var timeUpButtons: [UIButton] = []

    private let cardContainer = UIView()
    private let frontView = UIView()
    private let backView = UIView()
    private let frontScreen = UIView()
    private let backScreen = UIView()
    private let frontLabel = UILabel()
    private let backLabel = UILabel()
    private let backStack = UIStackView()
    private let backImageView = UIImageView()
    private let fallbackPlaceholderView = UIView()
    private let emojiLabel = UILabel()
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)
    private let errorLabel = UILabel()
    private let frontStickerContainer = UIView()
    private let frontStickerLabel = UILabel()
    private let frontStickerIcon = UIImageView()
    private let backStickerContainer = UIView()
    private let backStickerLabel = UILabel()
    private let backStickerIcon = UIImageView()
    private let stickerAssetNames = [
        "billiard",
        "candy-xbg",
        "car-xbg",
        "casset-xbg",
        "diary-xbg",
        "guitar",
        "heart-Xbg",
        "pin-Xbg",
        "record-xbg",
        "ribbon",
        "star-Xbg",
        "sunglass_xbg",
        "tape",
        "telephone-xbg"
    ]
    private var frontStickerDecorViews: [StickerDecorView] = []
    private var backStickerDecorViews: [StickerDecorView] = []
    private var frontStickerDecorBottomConstraints: [NSLayoutConstraint] = []
    private var backStickerDecorBottomConstraints: [NSLayoutConstraint] = []
    private var frontStickerDecorBottomBase: [CGFloat] = []
    private var backStickerDecorBottomBase: [CGFloat] = []
    private let buttonPanel = UIView()
    private let buttonStack = UIStackView()
    private let prevButton = UIButton(type: .system)
    private let nextButton = UIButton(type: .system)
    private var isAnimatingFlip = false
    private let emojiMapFileName = "emoji_map.json"
    private var emojiMap: [String: String] = [:]
    private var emojiTask: URLSessionDataTask?
    private var themeObserver: NSObjectProtocol?
    private let speechSynthesizer = AVSpeechSynthesizer()

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "フリップ"

        configureUI()
        configureTimePicker()
        words = presetWords ?? loadSavedWords()
        emojiMap = loadEmojiMap()
        if words.isEmpty {
            showAlert(title: "単語がありません", message: "先に単語を登録してください。")
        }
        showWord()
        applyTheme()
        themeObserver = NotificationCenter.default.addObserver(
            forName: ThemeManager.didChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyTheme()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if sessionStartTime == nil {
            sessionStartTime = Date()
            hasRecordedSession = false
            viewedWordIDs.removeAll()
            viewedWordIDSet.removeAll()
            recordViewedWordIfNeeded()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        dismissTimeUpModal()
        setNavigationLocked(false)
        speechSynthesizer.stopSpeaking(at: .immediate)
        recordFlipSessionIfNeeded()
    }

    private func configureUI() {
        timerStack.axis = .vertical
        timerStack.spacing = AppSpacing.s(8)
        timerStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(timerStack)

        timerTitleLabel.text = "フリップタイマー (0=制限なし)"
        timerTitleLabel.font = AppFont.jp(size: 14, weight: .regular)
        timerStack.addArrangedSubview(timerTitleLabel)

        timeTextField.borderStyle = .roundedRect
        timeTextField.font = AppFont.jp(size: 14)
        timeTextField.text = "0 (時間制限無し)"
        timerStack.addArrangedSubview(timeTextField)

        timerStartButton.setTitle("タイマー開始", for: .normal)
        timerStartButton.titleLabel?.font = AppFont.jp(size: 14, weight: .bold)
        timerStartButton.addTarget(self, action: #selector(startTimerTapped), for: .touchUpInside)
        timerStack.addArrangedSubview(timerStartButton)

        remainingTimeLabel.font = AppFont.jp(size: 14, weight: .bold)
        remainingTimeLabel.textColor = .secondaryLabel
        remainingTimeLabel.text = ""
        timerStack.addArrangedSubview(remainingTimeLabel)

        cardContainer.translatesAutoresizingMaskIntoConstraints = false
        cardContainer.backgroundColor = .clear
        view.addSubview(cardContainer)

        NSLayoutConstraint.activate([
            timerStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: AppSpacing.s(12)),
            timerStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AppSpacing.s(20)),
            timerStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AppSpacing.s(20)),
            cardContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cardContainer.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: AppSpacing.s(24)),
            cardContainer.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -AppSpacing.s(24)),
            cardContainer.topAnchor.constraint(greaterThanOrEqualTo: timerStack.bottomAnchor, constant: AppSpacing.s(12)),
        ])

        let cardPreferredWidth = cardContainer.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.78)
        cardPreferredWidth.priority = .defaultHigh
        cardPreferredWidth.isActive = true
        let cardMaxWidth = cardContainer.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.88)
        cardMaxWidth.priority = .required
        cardMaxWidth.isActive = true

        let cardPreferredHeight = cardContainer.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.34)
        cardPreferredHeight.priority = .defaultHigh
        cardPreferredHeight.isActive = true
        let cardMinHeight = cardContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 180)
        cardMinHeight.priority = .defaultLow
        cardMinHeight.isActive = true
        let cardTopPreferred = cardContainer.topAnchor.constraint(equalTo: timerStack.bottomAnchor, constant: AppSpacing.s(16))
        cardTopPreferred.priority = .defaultHigh
        cardTopPreferred.isActive = true

        [frontView, backView].forEach { cardSide in
            cardSide.translatesAutoresizingMaskIntoConstraints = false
            cardSide.layer.cornerRadius = 16
            cardSide.layer.borderWidth = 1
            cardSide.layer.borderColor = UIColor.systemGray4.cgColor
            cardSide.backgroundColor = .systemBackground
            cardSide.layer.shouldRasterize = true
            cardSide.layer.rasterizationScale = UIScreen.main.scale
            cardContainer.addSubview(cardSide)
            NSLayoutConstraint.activate([
                cardSide.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor),
                cardSide.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor),
                cardSide.topAnchor.constraint(equalTo: cardContainer.topAnchor),
                cardSide.bottomAnchor.constraint(equalTo: cardContainer.bottomAnchor),
            ])
        }

        frontLabel.translatesAutoresizingMaskIntoConstraints = false
        frontLabel.font = AppFont.jp(size: 28, weight: .bold)
        frontLabel.numberOfLines = 0
        frontLabel.textAlignment = .center
        frontScreen.translatesAutoresizingMaskIntoConstraints = false
        frontScreen.layer.cornerRadius = 14
        frontScreen.layer.borderWidth = 2
        frontScreen.clipsToBounds = true
        frontView.addSubview(frontScreen)
        frontScreen.addSubview(frontLabel)

        backLabel.translatesAutoresizingMaskIntoConstraints = false
        backLabel.font = AppFont.jp(size: 22, weight: .bold)
        backLabel.numberOfLines = 0
        backLabel.textAlignment = .center
        backImageView.translatesAutoresizingMaskIntoConstraints = false
        backImageView.contentMode = .scaleAspectFit
        backImageView.clipsToBounds = true
        fallbackPlaceholderView.translatesAutoresizingMaskIntoConstraints = false
        fallbackPlaceholderView.backgroundColor = .systemGray5
        fallbackPlaceholderView.layer.cornerRadius = 12
        fallbackPlaceholderView.clipsToBounds = true
        fallbackPlaceholderView.isHidden = true
        emojiLabel.translatesAutoresizingMaskIntoConstraints = false
        emojiLabel.font = AppFont.jp(size: 48, weight: .bold)
        emojiLabel.textAlignment = .center

        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        errorLabel.font = AppFont.jp(size: 12)
        errorLabel.textColor = .secondaryLabel
        errorLabel.numberOfLines = 0
        errorLabel.textAlignment = .center

        backStack.axis = .vertical
        backStack.spacing = AppSpacing.s(10)
        backStack.translatesAutoresizingMaskIntoConstraints = false
        backScreen.translatesAutoresizingMaskIntoConstraints = false
        backScreen.layer.cornerRadius = 14
        backScreen.layer.borderWidth = 2
        backScreen.clipsToBounds = true
        backView.addSubview(backScreen)
        backScreen.addSubview(backStack)
        backStack.addArrangedSubview(fallbackPlaceholderView)
        backStack.addArrangedSubview(backImageView)
        backStack.addArrangedSubview(backLabel)
        backStack.addArrangedSubview(errorLabel)
        fallbackPlaceholderView.addSubview(emojiLabel)

        NSLayoutConstraint.activate([
            frontScreen.leadingAnchor.constraint(equalTo: frontView.leadingAnchor, constant: AppSpacing.s(14)),
            frontScreen.trailingAnchor.constraint(equalTo: frontView.trailingAnchor, constant: -AppSpacing.s(14)),
            frontScreen.topAnchor.constraint(equalTo: frontView.topAnchor, constant: AppSpacing.s(14)),
            frontScreen.heightAnchor.constraint(equalTo: frontView.heightAnchor, multiplier: 0.48),
            frontLabel.leadingAnchor.constraint(equalTo: frontScreen.leadingAnchor, constant: AppSpacing.s(12)),
            frontLabel.trailingAnchor.constraint(equalTo: frontScreen.trailingAnchor, constant: -AppSpacing.s(12)),
            frontLabel.centerYAnchor.constraint(equalTo: frontScreen.centerYAnchor),
            backScreen.leadingAnchor.constraint(equalTo: backView.leadingAnchor, constant: AppSpacing.s(14)),
            backScreen.trailingAnchor.constraint(equalTo: backView.trailingAnchor, constant: -AppSpacing.s(14)),
            backScreen.topAnchor.constraint(equalTo: backView.topAnchor, constant: AppSpacing.s(14)),
            backScreen.heightAnchor.constraint(equalTo: backView.heightAnchor, multiplier: 0.6),
            backStack.leadingAnchor.constraint(equalTo: backScreen.leadingAnchor, constant: AppSpacing.s(12)),
            backStack.trailingAnchor.constraint(equalTo: backScreen.trailingAnchor, constant: -AppSpacing.s(12)),
            backStack.topAnchor.constraint(equalTo: backScreen.topAnchor, constant: AppSpacing.s(12)),
            backStack.bottomAnchor.constraint(equalTo: backScreen.bottomAnchor, constant: -AppSpacing.s(12)),
            fallbackPlaceholderView.heightAnchor.constraint(equalTo: backScreen.heightAnchor, multiplier: 0.6),
            backImageView.heightAnchor.constraint(equalTo: backScreen.heightAnchor, multiplier: 0.6),
        ])
        NSLayoutConstraint.activate([
            emojiLabel.centerXAnchor.constraint(equalTo: fallbackPlaceholderView.centerXAnchor),
            emojiLabel.centerYAnchor.constraint(equalTo: fallbackPlaceholderView.centerYAnchor),
        ])

        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.hidesWhenStopped = true
        backView.addSubview(loadingIndicator)
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: backView.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: backView.centerYAnchor),
        ])

        configureSticker(frontStickerContainer, label: frontStickerLabel, icon: frontStickerIcon)
        configureSticker(backStickerContainer, label: backStickerLabel, icon: backStickerIcon)
        frontView.addSubview(frontStickerContainer)
        backView.addSubview(backStickerContainer)
        NSLayoutConstraint.activate([
            frontStickerContainer.trailingAnchor.constraint(equalTo: frontView.trailingAnchor, constant: -AppSpacing.s(16)),
            frontStickerContainer.bottomAnchor.constraint(equalTo: frontView.bottomAnchor, constant: -AppSpacing.s(16)),
            backStickerContainer.trailingAnchor.constraint(equalTo: backView.trailingAnchor, constant: -AppSpacing.s(16)),
            backStickerContainer.bottomAnchor.constraint(equalTo: backView.bottomAnchor, constant: -AppSpacing.s(16)),
        ])
        frontStickerContainer.transform = CGAffineTransform(rotationAngle: -0.08)
        backStickerContainer.transform = CGAffineTransform(rotationAngle: -0.08)
        frontStickerContainer.isHidden = true
        backStickerContainer.isHidden = true

        configureStickerDecorations()

        backView.isHidden = true

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(flipCard))
        cardContainer.addGestureRecognizer(tapGesture)

        buttonPanel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(buttonPanel)

        buttonStack.axis = .horizontal
        buttonStack.spacing = AppSpacing.s(16)
        buttonStack.distribution = .fillEqually
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonPanel.addSubview(buttonStack)

        prevButton.setTitle("前の単語", for: .normal)
        prevButton.addTarget(self, action: #selector(showPrevWord), for: .touchUpInside)
        buttonStack.addArrangedSubview(prevButton)

        nextButton.setTitle("次の単語", for: .normal)
        nextButton.addTarget(self, action: #selector(showNextWord), for: .touchUpInside)
        buttonStack.addArrangedSubview(nextButton)

        NSLayoutConstraint.activate([
            buttonPanel.topAnchor.constraint(equalTo: cardContainer.bottomAnchor, constant: AppSpacing.s(28)),
            buttonPanel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            buttonPanel.widthAnchor.constraint(equalTo: cardContainer.widthAnchor),
            buttonPanel.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -AppSpacing.s(16)),
            buttonStack.leadingAnchor.constraint(equalTo: buttonPanel.leadingAnchor, constant: AppSpacing.s(16)),
            buttonStack.trailingAnchor.constraint(equalTo: buttonPanel.trailingAnchor, constant: -AppSpacing.s(16)),
            buttonStack.topAnchor.constraint(equalTo: buttonPanel.topAnchor, constant: AppSpacing.s(10)),
            buttonStack.bottomAnchor.constraint(equalTo: buttonPanel.bottomAnchor, constant: -AppSpacing.s(10)),
        ])

        let buttonPreferredHeight = buttonPanel.heightAnchor.constraint(equalTo: cardContainer.heightAnchor, multiplier: 0.22)
        buttonPreferredHeight.priority = .defaultHigh
        buttonPreferredHeight.isActive = true
        let buttonMinHeight = buttonPanel.heightAnchor.constraint(greaterThanOrEqualToConstant: 52)
        buttonMinHeight.priority = .defaultLow
        buttonMinHeight.isActive = true
    }

    private func configureSticker(_ container: UIView, label: UILabel, icon: UIImageView) {
        container.translatesAutoresizingMaskIntoConstraints = false
        container.layer.cornerRadius = 14
        container.layer.borderWidth = 2
        container.layer.shadowOpacity = 0.25
        container.layer.shadowOffset = CGSize(width: 0, height: 3)
        container.layer.shadowRadius = 4

        let stack = UIStackView(arrangedSubviews: [label, icon])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = AppSpacing.s(6)
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = AppFont.title(size: 12)
        label.text = "COOL!"
        label.textAlignment = .center

        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.contentMode = .scaleAspectFit
        icon.image = UIImage(systemName: "sparkle")

        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: 110),
            container.heightAnchor.constraint(equalToConstant: 36),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: AppSpacing.s(10)),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -AppSpacing.s(10)),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: AppSpacing.s(6)),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -AppSpacing.s(6)),
            icon.widthAnchor.constraint(equalToConstant: 16),
            icon.heightAnchor.constraint(equalToConstant: 16),
        ])
    }

    private func configureStickerDecorations() {
        let front = makeStickerDecorations(in: frontView)
        frontStickerDecorViews = front.views
        frontStickerDecorBottomConstraints = front.bottomConstraints
        frontStickerDecorBottomBase = front.baseConstants
        let back = makeStickerDecorations(in: backView)
        backStickerDecorViews = back.views
        backStickerDecorBottomConstraints = back.bottomConstraints
        backStickerDecorBottomBase = back.baseConstants
    }

    private func makeStickerDecorations(in cardSide: UIView) -> (views: [StickerDecorView], bottomConstraints: [NSLayoutConstraint], baseConstants: [CGFloat]) {
        let bottomLeft = StickerDecorView()
        let bottomRight = StickerDecorView()
        let bottomCenter = StickerDecorView()
        let decorations = [bottomLeft, bottomRight, bottomCenter]

        decorations.forEach { decor in
            decor.translatesAutoresizingMaskIntoConstraints = false
            cardSide.addSubview(decor)
            cardSide.bringSubviewToFront(decor)
        }

        let bottomLeftBottom = bottomLeft.bottomAnchor.constraint(equalTo: cardSide.bottomAnchor, constant: -AppSpacing.s(12))
        let bottomRightBottom = bottomRight.bottomAnchor.constraint(equalTo: cardSide.bottomAnchor, constant: -AppSpacing.s(12))
        let bottomCenterBottom = bottomCenter.bottomAnchor.constraint(equalTo: cardSide.bottomAnchor, constant: -AppSpacing.s(14))
        NSLayoutConstraint.activate([
            bottomLeftBottom,
            bottomLeft.leadingAnchor.constraint(equalTo: cardSide.leadingAnchor, constant: AppSpacing.s(12)),

            bottomRightBottom,
            bottomRight.trailingAnchor.constraint(equalTo: cardSide.trailingAnchor, constant: -AppSpacing.s(12)),

            bottomCenter.centerXAnchor.constraint(equalTo: cardSide.centerXAnchor),
            bottomCenterBottom,

            bottomLeft.widthAnchor.constraint(equalToConstant: 80),
            bottomLeft.heightAnchor.constraint(equalTo: bottomLeft.widthAnchor),
            bottomRight.widthAnchor.constraint(equalTo: bottomLeft.widthAnchor),
            bottomRight.heightAnchor.constraint(equalTo: bottomLeft.heightAnchor),
            bottomCenter.widthAnchor.constraint(equalTo: bottomLeft.widthAnchor),
            bottomCenter.heightAnchor.constraint(equalTo: bottomLeft.heightAnchor),
        ])

        let bases = [bottomLeftBottom.constant, bottomRightBottom.constant, bottomCenterBottom.constant]
        return (decorations, [bottomLeftBottom, bottomRightBottom, bottomCenterBottom], bases)
    }

    private func applyTheme() {
        let palette = ThemeManager.palette()
        ThemeManager.applyBackground(to: view)
        ThemeManager.applyNavigationAppearance(to: navigationController)

        [frontView, backView].forEach { cardSide in
            cardSide.backgroundColor = UIColor.black.withAlphaComponent(0.85)
            cardSide.layer.borderColor = palette.border.cgColor
            cardSide.layer.borderWidth = 2
            cardSide.layer.shadowColor = palette.border.cgColor
            cardSide.layer.shadowOpacity = 0.15
            cardSide.layer.shadowOffset = CGSize(width: 0, height: 4)
            cardSide.layer.shadowRadius = 8
        }
        [frontScreen, backScreen].forEach { screen in
            screen.backgroundColor = palette.surfaceAlt
            screen.layer.borderColor = palette.border.cgColor
            screen.layer.shadowColor = palette.accent.cgColor
            screen.layer.shadowOpacity = 0.35
            screen.layer.shadowOffset = CGSize(width: 0, height: 4)
            screen.layer.shadowRadius = 10
        }
        frontLabel.textColor = .black
        backLabel.textColor = .black
        errorLabel.textColor = palette.mutedText
        fallbackPlaceholderView.backgroundColor = palette.surfaceAlt
        loadingIndicator.color = palette.accentStrong
        [frontStickerContainer, backStickerContainer].forEach { sticker in
            sticker.backgroundColor = palette.accent
            sticker.layer.borderColor = palette.border.cgColor
            sticker.layer.shadowColor = palette.border.cgColor
        }
        frontStickerLabel.textColor = palette.text
        backStickerLabel.textColor = palette.text
        frontStickerIcon.tintColor = palette.text
        backStickerIcon.tintColor = palette.text

        prevButton.titleLabel?.font = AppFont.jp(size: 16, weight: .bold)
        nextButton.titleLabel?.font = AppFont.jp(size: 16, weight: .bold)
        ThemeManager.styleSecondaryButton(prevButton)
        ThemeManager.stylePrimaryButton(nextButton)
        ThemeManager.stylePrimaryButton(timerStartButton)
        timerTitleLabel.textColor = palette.text
        remainingTimeLabel.textColor = palette.mutedText

        buttonPanel.backgroundColor = palette.surface
        buttonPanel.layer.cornerRadius = 16
        buttonPanel.layer.borderWidth = 2
        buttonPanel.layer.borderColor = palette.border.cgColor
        buttonPanel.layer.shadowColor = palette.border.cgColor
        buttonPanel.layer.shadowOpacity = 0.2
        buttonPanel.layer.shadowOffset = CGSize(width: 0, height: 3)
        buttonPanel.layer.shadowRadius = 6
        updateTimeUpModalTheme()
    }

    private func applyStickerDecorations() {
        let count = Int.random(in: 2...3)
        let positions = Array(0..<frontStickerDecorViews.count).shuffled().prefix(count)
        let assets = stickerAssetNames.shuffled()
        let rotationBase: [CGFloat] = [-0.12, 0.1, -0.08]
        let rotations = Dictionary(uniqueKeysWithValues: positions.map { index in
            let jitter = CGFloat.random(in: -0.05...0.05)
            return (index, rotationBase[index] + jitter)
        })
        applyStickerDecorations(to: frontStickerDecorViews,
                                positions: Array(positions),
                                assets: assets,
                                rotations: rotations)
        applyStickerDecorations(to: backStickerDecorViews,
                                positions: Array(positions),
                                assets: assets,
                                rotations: rotations)
        randomizeStickerDecorationOffsets(frontStickerDecorBottomConstraints, baseConstants: frontStickerDecorBottomBase)
        randomizeStickerDecorationOffsets(backStickerDecorBottomConstraints, baseConstants: backStickerDecorBottomBase)
    }

    private func randomizeStickerDecorationOffsets(_ constraints: [NSLayoutConstraint], baseConstants: [CGFloat]) {
        for (index, constraint) in constraints.enumerated() {
            let base = index < baseConstants.count ? baseConstants[index] : constraint.constant
            let jitter = CGFloat.random(in: -10...6)
            let proposed = base + jitter - 4
            let minConstant: CGFloat = -28
            let maxConstant: CGFloat = -8
            constraint.constant = min(max(proposed, minConstant), maxConstant)
        }
    }

    private func applyStickerDecorations(to views: [StickerDecorView],
                                         positions: [Int],
                                         assets: [String],
                                         rotations: [Int: CGFloat]) {
        views.enumerated().forEach { index, view in
            view.isHidden = true
            view.transform = .identity
            view.setImage(nil)
        }
        for (offset, position) in positions.enumerated() {
            guard position < views.count else { continue }
            let name = assets[offset % assets.count]
            let image = loadStickerAsset(named: name)
            let view = views[position]
            view.setImage(image)
            view.isHidden = (image == nil)
            if let angle = rotations[position] {
                view.transform = CGAffineTransform(rotationAngle: angle)
            }
        }
    }

    private func loadStickerAsset(named name: String) -> UIImage? {
        if let image = UIImage(named: name) {
            return image
        }
        let candidates = [name, "\(name).jpg", "\(name).png"]
        for candidate in candidates {
            if let image = UIImage(named: candidate) {
                return image
            }
            if let url = Bundle.main.url(forResource: candidate, withExtension: nil),
               let image = UIImage(contentsOfFile: url.path) {
                return image
            }
            let parts = candidate.split(separator: ".", omittingEmptySubsequences: false)
            if parts.count >= 2 {
                let base = parts.dropLast().joined(separator: ".")
                let ext = String(parts.last ?? "")
                if let url = Bundle.main.url(forResource: base, withExtension: ext),
                   let image = UIImage(contentsOfFile: url.path) {
                    return image
                }
            }
        }
        return nil
    }

    private func configureTimePicker() {
        timePicker.tag = 1
        timePicker.delegate = self
        timePicker.dataSource = self
        timeTextField.inputView = timePicker
        timeTextField.inputAccessoryView = makeToolbar()
        timeTextField.tintColor = .clear

        if let index = timeOptionsSec.firstIndex(of: selectedTimeSeconds) {
            timePicker.selectRow(index, inComponent: 0, animated: false)
        } else {
            timeTextField.text = "0 (時間制限無し)"
            timePicker.selectRow(0, inComponent: 0, animated: false)
            selectedTimeSeconds = 0
        }
    }

    private func makeToolbar() -> UIToolbar {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done = UIBarButtonItem(title: "完了", style: .done, target: self, action: #selector(dismissPicker))
        toolbar.items = [spacer, done]
        return toolbar
    }

    @objc private func dismissPicker() {
        view.endEditing(true)
    }

    @objc private func startTimerTapped() {
        startTimerIfNeeded(limitSeconds: selectedTimeSeconds)
    }

    private func startTimerIfNeeded(limitSeconds: Int) {
        timer?.invalidate()
        timer = nil
        endTime = nil
        remainingTimeLabel.text = ""

        guard limitSeconds > 0 else {
            setNavigationLocked(false)
            timeTextField.isEnabled = true
            return
        }

        endTime = Date().addingTimeInterval(TimeInterval(limitSeconds))
        timerStartButton.isEnabled = false
        timeTextField.isEnabled = false
        setNavigationLocked(true)
        updateRemainingTime()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateRemainingTime()
        }
    }

    private func updateRemainingTime() {
        guard let endTime else { return }
        let remaining = Int(endTime.timeIntervalSinceNow.rounded(.down))
        if remaining <= 0 {
            remainingTimeLabel.text = "残り時間: 0秒"
            finishTimer()
            return
        }
        remainingTimeLabel.text = "残り時間: \(remaining)秒"
    }

    private func finishTimer() {
        timer?.invalidate()
        timer = nil
        endTime = nil
        timerStartButton.isEnabled = true
        timeTextField.isEnabled = true
        showTimeUpModal()
    }

    private func setNavigationLocked(_ locked: Bool) {
        navigationItem.hidesBackButton = locked
        navigationController?.interactivePopGestureRecognizer?.isEnabled = !locked
    }

    deinit {
        if let observer = themeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func savedWordsFileURL() -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory,
                                                 in: .userDomainMask).first!
        return documents.appendingPathComponent(savedWordsFileName)
    }

    private func resultsFileURL() -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory,
                                                 in: .userDomainMask).first!
        return documents.appendingPathComponent(resultsFileName)
    }

    private func loadSavedWords() -> [SavedWord] {
        let fileURL = savedWordsFileURL()
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([SavedWord].self, from: data) {
            return decoded
        }
        return []
    }

    private func recordFlipSessionIfNeeded() {
        guard let sessionStartTime, !hasRecordedSession else { return }
        let elapsed = Date().timeIntervalSince(sessionStartTime)
        if elapsed < 1 {
            return
        }
        let wordMap = Dictionary(uniqueKeysWithValues: words.map { ($0.id, $0) })
        let questions = viewedWordIDs.enumerated().compactMap { index, id -> SessionQuestion? in
            guard let word = wordMap[id] else { return nil }
            return SessionQuestion(
                index: index + 1,
                type: "flip",
                direction: "none",
                wordId: word.id,
                prompt: word.english,
                correctAnswer: word.japanese,
                userAnswer: "",
                correct: false,
                answerTimeSec: 0
            )
        }
        let session = SessionResult(
            timestamp: isoTimestamp(),
            reason: "flip",
            modeLabel: "フリップ",
            directionLabel: nil,
            totalQuestionsGenerated: words.count,
            answered: 0,
            score: 0,
            accuracy: 0,
            totalElapsedSec: elapsed,
            questions: questions
        )
        var db = loadResults()
        db.sessions.append(session)
        saveResults(db)
        hasRecordedSession = true
        self.sessionStartTime = nil
    }

    private func loadResults() -> ResultsDatabase {
        let url = resultsFileURL()
        guard let data = try? Data(contentsOf: url) else {
            return ResultsDatabase(sessions: [])
        }
        if let decoded = try? JSONDecoder().decode(ResultsDatabase.self, from: data) {
            return decoded
        }
        return ResultsDatabase(sessions: [])
    }

    private func saveResults(_ db: ResultsDatabase) {
        let url = resultsFileURL()
        guard let data = try? JSONEncoder().encode(db) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private func isoTimestamp() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date())
    }

    private func showWord() {
        guard !words.isEmpty else {
            frontLabel.text = "単語がありません"
            backLabel.text = ""
            updateCardFonts(frontText: frontLabel.text ?? "", backText: backLabel.text ?? "")
            backImageView.image = nil
            backImageView.isHidden = true
            fallbackPlaceholderView.isHidden = true
            errorLabel.text = ""
            loadingIndicator.stopAnimating()
            prevButton.isEnabled = false
            nextButton.isEnabled = false
            return
        }
        let word = words[currentIndex]
        recordViewedWordIfNeeded()
        frontLabel.text = word.english
        backLabel.text = word.japanese
        updateCardFonts(frontText: word.english, backText: word.japanese)
        applyStickerDecorations()
        loadComicImage(for: word)
        setCardSide(isFront: true, animated: false)
        speakEnglish(word.english)
    }

    private func updateCardFonts(frontText: String, backText: String) {
        frontLabel.font = fontForText(frontText, jpSize: 26, enSize: 34, jpWeight: .light, enWeight: .light)
        backLabel.font = fontForText(backText, jpSize: 22, enSize: 28, jpWeight: .light, enWeight: .light)
    }

    private func fontForText(_ text: String,
                             jpSize: CGFloat,
                             enSize: CGFloat,
                             jpWeight: UIFont.Weight,
                             enWeight: UIFont.Weight) -> UIFont {
        if text.range(of: "[\\p{Hiragana}\\p{Katakana}\\p{Han}]", options: .regularExpression) != nil {
            return AppFont.jp(size: jpSize, weight: jpWeight)
        }
        return AppFont.en(size: enSize, weight: enWeight)
    }

    private func recordViewedWordIfNeeded() {
        guard currentIndex >= 0, currentIndex < words.count else { return }
        let id = words[currentIndex].id
        if !viewedWordIDSet.contains(id) {
            viewedWordIDSet.insert(id)
            viewedWordIDs.append(id)
        }
    }

    private func setCardSide(isFront: Bool, animated: Bool) {
        let fromView = isFront ? backView : frontView
        let toView = isFront ? frontView : backView
        guard animated else {
            fromView.isHidden = true
            toView.isHidden = false
            cardContainer.layoutIfNeeded()
            isFlipped = !isFront
            return
        }

        guard !isAnimatingFlip else { return }
        isAnimatingFlip = true
        view.layoutIfNeeded()
        cardContainer.layoutIfNeeded()

        let options: UIView.AnimationOptions = isFront ? .transitionFlipFromLeft : .transitionFlipFromRight
        UIView.transition(with: cardContainer,
                          duration: 0.26,
                          options: [options, .curveEaseInOut, .allowUserInteraction]) {
            fromView.isHidden = true
            toView.isHidden = false
        } completion: { [weak self] _ in
            self?.isAnimatingFlip = false
        }
        isFlipped = !isFront
    }

    private func speakEnglish(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        speechSynthesizer.speak(utterance)
    }

    @objc private func flipCard() {
        guard !words.isEmpty, !isAnimatingFlip else { return }
        setCardSide(isFront: isFlipped, animated: true)
    }

    @objc private func showNextWord() {
        guard !words.isEmpty else { return }
        let nextIndex = currentIndex + 1
        if nextIndex >= words.count {
            currentIndex = 0
            showAlert(title: "お疲れさま！", message: "全ての単語を一周しました！")
        } else {
            currentIndex = nextIndex
        }
        showWord()
    }

    @objc private func showPrevWord() {
        guard !words.isEmpty else { return }
        if currentIndex == 0 {
            currentIndex = words.count - 1
        } else {
            currentIndex -= 1
        }
        showWord()
    }

    private func loadComicImage(for word: SavedWord) {
        errorLabel.text = ""
        backImageView.image = nil
        backImageView.isHidden = true
        fallbackPlaceholderView.isHidden = false
        emojiLabel.text = "..."
        if let fileName = word.illustrationImageFileName,
           let image = loadIllustrationImage(fileName: fileName) {
            backImageView.image = image
            backImageView.isHidden = false
            fallbackPlaceholderView.isHidden = true
            loadingIndicator.stopAnimating()
            return
        }
        loadEmoji(for: word)
        loadingIndicator.stopAnimating()
    }

    private func loadIllustrationImage(fileName: String) -> UIImage? {
        if let sticker = StickerStore.loadStickerImage(fileName: fileName) {
            return sticker
        }
        let documents = FileManager.default.urls(for: .documentDirectory,
                                                 in: .userDomainMask).first!
        let url = documents.appendingPathComponent(fileName)
        return UIImage(contentsOfFile: url.path)
    }

    private func loadCachedComicImage(for word: SavedWord) -> UIImage? {
        let url = comicFileURL(for: word)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    private func saveComicImage(_ data: Data, for word: SavedWord) {
        let url = comicFileURL(for: word)
        try? data.write(to: url, options: .atomic)
    }

    private func comicFileURL(for word: SavedWord) -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory,
                                                 in: .userDomainMask).first!
        let safeName = sanitizeFileName(word.english)
        return documents.appendingPathComponent("comic_\(safeName).png")
    }

    private func sanitizeFileName(_ text: String) -> String {
        let pattern = "[^A-Za-z0-9_-]"
        return text.replacingOccurrences(of: pattern, with: "_", options: .regularExpression)
    }

    private func loadEmoji(for word: SavedWord) {
        let key = emojiKey(for: word)
        if let cached = emojiMap[key] {
            emojiLabel.text = cached
            return
        }
        emojiTask?.cancel()
        guard let apiKey = loadGeminiAPIKey(), !apiKey.isEmpty else {
            emojiLabel.text = "✨"
            errorLabel.text = "絵文字の取得に失敗しました"
            return
        }

        let prompt = """
        Return exactly one emoji that best represents the meaning of the word.
        Word: "\(word.english)"
        Meaning: "\(word.japanese)"
        Scenario: "\(word.illustrationScenario ?? "none")"
        Output only the emoji, no text.
        """

        let requestBody = GeminiTextRequest(
            contents: [
                .init(parts: [.init(text: prompt)])
            ]
        )

        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=\(apiKey)") else {
            emojiLabel.text = "✨"
            errorLabel.text = "絵文字の取得に失敗しました"
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(requestBody)

        emojiTask = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }
            if error != nil {
                DispatchQueue.main.async {
                    self.emojiLabel.text = "✨"
                    self.errorLabel.text = "絵文字の取得に失敗しました"
                }
                return
            }
            let statusCode = (response as? HTTPURLResponse)?.statusCode
            let preview = data.flatMap { String(data: $0.prefix(800), encoding: .utf8) } ?? "<empty>"
            print("Gemini status: \(statusCode ?? -1)")
            print("Gemini body preview: \(preview)")

            guard let data,
                  let emoji = Self.decodeEmoji(from: data) else {
                DispatchQueue.main.async {
                    self.emojiLabel.text = "✨"
                    self.errorLabel.text = "絵文字の取得に失敗しました"
                }
                return
            }
            DispatchQueue.main.async {
                self.emojiLabel.text = emoji
                self.errorLabel.text = ""
                self.emojiMap[key] = emoji
                self.saveEmojiMap()
            }
        }
        emojiTask?.resume()
    }

    private func emojiKey(for word: SavedWord) -> String {
        return "\(word.english.lowercased())|\(word.japanese)"
    }

    private func loadEmojiMap() -> [String: String] {
        let url = emojiMapFileURL()
        guard let data = try? Data(contentsOf: url) else { return [:] }
        return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
    }

    private func saveEmojiMap() {
        let url = emojiMapFileURL()
        guard let data = try? JSONEncoder().encode(emojiMap) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private func emojiMapFileURL() -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory,
                                                 in: .userDomainMask).first!
        return documents.appendingPathComponent(emojiMapFileName)
    }

    private func loadGeminiAPIKey() -> String? {
        return (Bundle.main.object(forInfoDictionaryKey: "GeminiAPIKey") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func decodeEmoji(from data: Data) -> String? {
        let decoded = try? JSONDecoder().decode(GeminiTextResponse.self, from: data)
        let text = decoded?.candidates?.first?.content?.parts?.first?.text?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        for ch in text {
            if ch.unicodeScalars.contains(where: { $0.properties.isEmoji }) {
                return String(ch)
            }
        }
        return nil
    }


    private func showAlert(title: String, message: String) {
        presentUnifiedModal(title: title,
                            message: message,
                            actions: [UnifiedModalAction(title: "OK")])
    }

    private func showTimeUpModal() {
        guard timeUpOverlay == nil else { return }
        let overlay = UIControl()
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.accessibilityViewIsModal = true

        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "時間切れ"
        titleLabel.textAlignment = .center

        let messageLabel = UILabel()
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.text = "前画面に戻りますか？"
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center

        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = AppSpacing.s(8)

        let backButton = makeTimeUpButton(title: "戻る", action: #selector(handleTimeUpBack))
        let continueButton = makeTimeUpButton(title: "続ける", action: #selector(handleTimeUpContinue))

        [backButton, continueButton].forEach { button in
            stack.addArrangedSubview(button)
            button.heightAnchor.constraint(equalToConstant: 36).isActive = true
        }

        container.addSubview(titleLabel)
        container.addSubview(messageLabel)
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

            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: AppSpacing.s(8)),
            messageLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: AppSpacing.s(16)),
            messageLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -AppSpacing.s(16)),

            stack.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: AppSpacing.s(12)),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: AppSpacing.s(16)),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -AppSpacing.s(16)),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -AppSpacing.s(16)),
        ])

        timeUpOverlay = overlay
        timeUpContainer = container
        timeUpTitleLabel = titleLabel
        timeUpMessageLabel = messageLabel
        timeUpButtons = [backButton, continueButton]
        updateTimeUpModalTheme()

        overlay.alpha = 0
        container.alpha = 0
        container.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseOut]) {
            overlay.alpha = 1
            container.alpha = 1
            container.transform = .identity
        }
    }

    @objc private func handleTimeUpBack() {
        dismissTimeUpModal()
        setNavigationLocked(false)
        navigationController?.popViewController(animated: true)
    }

    @objc private func handleTimeUpContinue() {
        dismissTimeUpModal()
        setNavigationLocked(false)
    }

    @objc private func dismissTimeUpModal() {
        guard let overlay = timeUpOverlay, let container = timeUpContainer else { return }
        UIView.animate(withDuration: 0.15, delay: 0, options: [.curveEaseIn]) {
            overlay.alpha = 0
            container.alpha = 0
            container.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        } completion: { [weak self] _ in
            overlay.removeFromSuperview()
            self?.timeUpOverlay = nil
            self?.timeUpContainer = nil
            self?.timeUpTitleLabel = nil
            self?.timeUpMessageLabel = nil
            self?.timeUpButtons = []
        }
    }

    private func makeTimeUpButton(title: String, action: Selector) -> UIButton {
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

    private func updateTimeUpModalTheme() {
        guard let overlay = timeUpOverlay,
              let container = timeUpContainer,
              let titleLabel = timeUpTitleLabel,
              let messageLabel = timeUpMessageLabel else { return }
        let palette = ThemeManager.palette()
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        container.backgroundColor = palette.surface
        container.layer.borderWidth = 2
        container.layer.borderColor = palette.border.cgColor
        titleLabel.font = AppFont.jp(size: 16, weight: .bold)
        titleLabel.textColor = palette.text
        messageLabel.font = AppFont.jp(size: 12, weight: .regular)
        messageLabel.textColor = palette.text
        timeUpButtons.forEach { button in
            button.backgroundColor = palette.surfaceAlt
            button.layer.borderColor = palette.border.cgColor
            button.setTitleColor(palette.text, for: .normal)
        }
    }

    private func generateLocalComicImage(for word: SavedWord) -> UIImage? {
        let size = CGSize(width: 700, height: 420)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let cg = context.cgContext
            let padding: CGFloat = 20
            let gutter: CGFloat = 16
            let panelWidth = (size.width - padding * 2 - gutter) / 2
            let panelHeight = size.height - padding * 2
            let leftPanel = CGRect(x: padding, y: padding, width: panelWidth, height: panelHeight)
            let rightPanel = CGRect(x: padding + panelWidth + gutter, y: padding, width: panelWidth, height: panelHeight)

            UIColor.white.setFill()
            cg.fill(CGRect(origin: .zero, size: size))

            UIColor.black.setStroke()
            cg.setLineWidth(3)
            cg.stroke(leftPanel)
            cg.stroke(rightPanel)

            let mood = inferMood(for: word)
            drawPanel(in: leftPanel, mood: mood, style: .setup, word: word, context: cg)
            drawPanel(in: rightPanel, mood: mood, style: .punchline, word: word, context: cg)
        }
    }

    private enum Mood {
        case happy
        case sad
        case angry
        case calm
        case neutral
    }

    private enum PanelStyle {
        case setup
        case punchline
    }

    private func inferMood(for word: SavedWord) -> Mood {
        let text = "\(word.english) \(word.japanese) \(word.illustrationScenario ?? "")".lowercased()
        if text.contains("happy") || text.contains("joy") || text.contains("love") || text.contains("kind") || text.contains("benevolent") || text.contains("嬉") || text.contains("幸") || text.contains("優") || text.contains("楽") {
            return .happy
        }
        if text.contains("sad") || text.contains("fear") || text.contains("tired") || text.contains("悲") || text.contains("寂") || text.contains("不安") {
            return .sad
        }
        if text.contains("angry") || text.contains("rage") || text.contains("怒") || text.contains("苛") {
            return .angry
        }
        if text.contains("calm") || text.contains("quiet") || text.contains("静") || text.contains("落ち着") {
            return .calm
        }
        return .neutral
    }

    private enum Scene {
        case kindness
        case study
        case bubble
        case sunset
        case rain
        case music
        case chance
        case respect
        case bias
        case honesty
        case headache
        case conviction
        case curiosity
        case hamburger
        case bird
        case none
    }

    private func inferScene(for word: SavedWord) -> Scene {
        let text = "\(word.english) \(word.japanese) \(word.illustrationScenario ?? "")".lowercased()
        if text.contains("kind") || text.contains("benevolent") || text.contains("優") || text.contains("親切") {
            return .kindness
        }
        if text.contains("study") || text.contains("diligent") || text.contains("勉強") || text.contains("努力") {
            return .study
        }
        if text.contains("bubble") || text.contains("ephemeral") || text.contains("シャボン") || text.contains("はかない") {
            return .bubble
        }
        if text.contains("sunset") || text.contains("夕日") || text.contains("黄昏") {
            return .sunset
        }
        if text.contains("rain") || text.contains("umbrella") || text.contains("雨") || text.contains("傘") {
            return .rain
        }
        if text.contains("music") || text.contains("sound") || text.contains("騒音") || text.contains("音") {
            return .music
        }
        if text.contains("chance") || text.contains("accident") || text.contains("偶然") || text.contains("たまたま") {
            return .chance
        }
        if text.contains("respect") || text.contains("敬意") || text.contains("尊重") || text.contains("礼") {
            return .respect
        }
        if text.contains("bias") || text.contains("偏") || text.contains("先入観") {
            return .bias
        }
        if text.contains("honest") || text.contains("honestly") || text.contains("正直") || text.contains("誠実") {
            return .honesty
        }
        if text.contains("headache") || text.contains("頭痛") {
            return .headache
        }
        if text.contains("確信") || text.contains("conviction") || text.contains("confident") {
            return .conviction
        }
        if text.contains("curious") || text.contains("curiosity") || text.contains("好奇心") {
            return .curiosity
        }
        if text.contains("hamburger") || text.contains("ハンバーガー") {
            return .hamburger
        }
        if text.contains("bird") || text.contains("鳥") {
            return .bird
        }
        return .none
    }

    private func shouldDrawPerson(for word: SavedWord, scene: Scene) -> Bool {
        let text = "\(word.english) \(word.japanese) \(word.illustrationScenario ?? "")".lowercased()
        if text.contains("umbrella") || text.contains("傘") {
            return false
        }
        if text.contains("hamburger") || text.contains("ハンバーガー") {
            return false
        }
        if text.contains("bird") || text.contains("鳥") {
            return false
        }
        switch scene {
        case .sunset, .bubble, .music, .chance, .hamburger, .bird:
            return false
        default:
            return true
        }
    }

    private func drawPanel(in rect: CGRect,
                           mood: Mood,
                           style: PanelStyle,
                           word: SavedWord,
                           context: CGContext) {
        let lineWidth: CGFloat = 3
        context.setLineWidth(lineWidth)
        UIColor.black.setStroke()
        UIColor.black.setFill()

        let scene = inferScene(for: word)
        let drawPerson = shouldDrawPerson(for: word, scene: scene)
        if drawPerson {
            let figureX = rect.midX
            let headRadius: CGFloat = min(rect.width, rect.height) * 0.12
            let headCenter = CGPoint(x: figureX, y: rect.minY + headRadius + 22)
            context.addEllipse(in: CGRect(x: headCenter.x - headRadius,
                                          y: headCenter.y - headRadius,
                                          width: headRadius * 2,
                                          height: headRadius * 2))
            context.strokePath()

            let bodyTop = CGPoint(x: figureX, y: headCenter.y + headRadius)
            let bodyBottom = CGPoint(x: figureX, y: bodyTop.y + rect.height * 0.28)
            context.move(to: bodyTop)
            context.addLine(to: bodyBottom)
            context.strokePath()

            let armY = bodyTop.y + rect.height * 0.08
            context.move(to: CGPoint(x: figureX - rect.width * 0.18, y: armY))
            context.addLine(to: CGPoint(x: figureX + rect.width * 0.18, y: armY))
            context.strokePath()

            context.move(to: bodyBottom)
            context.addLine(to: CGPoint(x: figureX - rect.width * 0.12, y: bodyBottom.y + rect.height * 0.18))
            context.move(to: bodyBottom)
            context.addLine(to: CGPoint(x: figureX + rect.width * 0.12, y: bodyBottom.y + rect.height * 0.18))
            context.strokePath()

            drawFace(mood: mood, center: headCenter, radius: headRadius, context: context)
        }
        drawSceneProp(in: rect, scene: scene, style: style, context: context)

        if style == .setup {
            drawThoughtBubble(in: rect, context: context)
        } else {
            drawActionLines(in: rect, mood: mood, context: context)
        }
    }

    private func drawFace(mood: Mood, center: CGPoint, radius: CGFloat, context: CGContext) {
        let eyeOffsetX = radius * 0.35
        let eyeOffsetY = radius * -0.2
        let eyeRadius = radius * 0.08
        let leftEye = CGRect(x: center.x - eyeOffsetX - eyeRadius,
                             y: center.y + eyeOffsetY - eyeRadius,
                             width: eyeRadius * 2,
                             height: eyeRadius * 2)
        let rightEye = CGRect(x: center.x + eyeOffsetX - eyeRadius,
                              y: center.y + eyeOffsetY - eyeRadius,
                              width: eyeRadius * 2,
                              height: eyeRadius * 2)
        context.addEllipse(in: leftEye)
        context.addEllipse(in: rightEye)
        context.fillPath()

        let mouthWidth = radius * 0.7
        let mouthY = center.y + radius * 0.3
        let mouthRect = CGRect(x: center.x - mouthWidth / 2,
                               y: mouthY,
                               width: mouthWidth,
                               height: radius * 0.4)
        switch mood {
        case .happy:
            context.addArc(center: CGPoint(x: mouthRect.midX, y: mouthRect.minY),
                           radius: mouthWidth / 2,
                           startAngle: 0,
                           endAngle: .pi,
                           clockwise: false)
        case .sad:
            context.addArc(center: CGPoint(x: mouthRect.midX, y: mouthRect.maxY),
                           radius: mouthWidth / 2,
                           startAngle: .pi,
                           endAngle: 0,
                           clockwise: false)
        case .angry:
            context.move(to: CGPoint(x: mouthRect.minX, y: mouthRect.midY))
            context.addLine(to: CGPoint(x: mouthRect.maxX, y: mouthRect.midY))
            drawAngryEyebrows(center: center, radius: radius, context: context)
        case .calm, .neutral:
            context.move(to: CGPoint(x: mouthRect.minX, y: mouthRect.midY))
            context.addLine(to: CGPoint(x: mouthRect.maxX, y: mouthRect.midY))
        }
        context.strokePath()
    }

    private func drawAngryEyebrows(center: CGPoint, radius: CGFloat, context: CGContext) {
        let offsetY = radius * -0.45
        let length = radius * 0.35
        context.move(to: CGPoint(x: center.x - radius * 0.45, y: center.y + offsetY))
        context.addLine(to: CGPoint(x: center.x - radius * 0.1, y: center.y + offsetY + length * 0.3))
        context.move(to: CGPoint(x: center.x + radius * 0.45, y: center.y + offsetY))
        context.addLine(to: CGPoint(x: center.x + radius * 0.1, y: center.y + offsetY + length * 0.3))
        context.strokePath()
    }

    private func drawThoughtBubble(in rect: CGRect, context: CGContext) {
        let bubbleRadius = rect.width * 0.12
        let bubbleCenter = CGPoint(x: rect.maxX - bubbleRadius - 16,
                                   y: rect.minY + bubbleRadius + 24)
        context.addEllipse(in: CGRect(x: bubbleCenter.x - bubbleRadius,
                                      y: bubbleCenter.y - bubbleRadius,
                                      width: bubbleRadius * 2,
                                      height: bubbleRadius * 2))
        context.strokePath()

        let smallRadius = bubbleRadius * 0.3
        context.addEllipse(in: CGRect(x: bubbleCenter.x - bubbleRadius - smallRadius * 1.6,
                                      y: bubbleCenter.y + bubbleRadius * 0.7,
                                      width: smallRadius * 2,
                                      height: smallRadius * 2))
        context.strokePath()
    }

    private func drawActionLines(in rect: CGRect, mood: Mood, context: CGContext) {
        guard mood == .happy || mood == .angry else { return }
        let startX = rect.minX + rect.width * 0.1
        let endX = rect.minX + rect.width * 0.3
        let baseY = rect.maxY - rect.height * 0.15
        for i in 0..<3 {
            let y = baseY - CGFloat(i) * 8
            context.move(to: CGPoint(x: startX, y: y))
            context.addLine(to: CGPoint(x: endX, y: y))
        }
        context.strokePath()
    }

    private func drawSceneProp(in rect: CGRect, scene: Scene, style: PanelStyle, context: CGContext) {
        switch scene {
        case .kindness:
            drawUmbrella(in: rect, context: context)
        case .study:
            drawBook(in: rect, context: context)
        case .bubble:
            drawBubbles(in: rect, context: context)
        case .sunset:
            drawSun(in: rect, context: context)
        case .rain:
            drawUmbrella(in: rect, context: context)
        case .music:
            drawSoundWaves(in: rect, context: context)
        case .chance:
            drawDice(in: rect, context: context)
        case .respect:
            drawBow(in: rect, context: context)
        case .bias:
            drawScale(in: rect, context: context)
        case .honesty:
            drawOpenHeart(in: rect, context: context)
        case .headache:
            drawHeadacheLines(in: rect, context: context)
        case .conviction:
            drawFlag(in: rect, context: context)
        case .curiosity:
            drawMagnifyingGlass(in: rect, context: context)
        case .hamburger:
            drawHamburger(in: rect, context: context)
        case .bird:
            drawBird(in: rect, context: context)
        case .none:
            break
        }
    }

    private func drawUmbrella(in rect: CGRect, context: CGContext) {
        let width = rect.width * 0.28
        let height = rect.height * 0.12
        let origin = CGPoint(x: rect.minX + rect.width * 0.1, y: rect.maxY - rect.height * 0.28)
        let arcCenter = CGPoint(x: origin.x + width / 2, y: origin.y + height / 2)
        context.addArc(center: arcCenter, radius: width / 2, startAngle: .pi, endAngle: 0, clockwise: false)
        context.strokePath()
        context.move(to: CGPoint(x: arcCenter.x, y: arcCenter.y + height / 2))
        context.addLine(to: CGPoint(x: arcCenter.x, y: arcCenter.y + height / 2 + rect.height * 0.12))
        context.strokePath()
    }

    private func drawBook(in rect: CGRect, context: CGContext) {
        let bookRect = CGRect(x: rect.maxX - rect.width * 0.32,
                              y: rect.maxY - rect.height * 0.3,
                              width: rect.width * 0.22,
                              height: rect.height * 0.16)
        context.stroke(bookRect)
        context.move(to: CGPoint(x: bookRect.midX, y: bookRect.minY))
        context.addLine(to: CGPoint(x: bookRect.midX, y: bookRect.maxY))
        context.strokePath()
    }

    private func drawBubbles(in rect: CGRect, context: CGContext) {
        let base = CGPoint(x: rect.maxX - rect.width * 0.2, y: rect.minY + rect.height * 0.25)
        for i in 0..<3 {
            let r = rect.width * (0.03 + CGFloat(i) * 0.01)
            let offset = CGFloat(i) * 18
            let bubble = CGRect(x: base.x + offset,
                                y: base.y + offset,
                                width: r * 2,
                                height: r * 2)
            context.strokeEllipse(in: bubble)
        }
    }

    private func drawSun(in rect: CGRect, context: CGContext) {
        let radius = rect.width * 0.08
        let center = CGPoint(x: rect.minX + rect.width * 0.18, y: rect.minY + rect.height * 0.22)
        context.strokeEllipse(in: CGRect(x: center.x - radius,
                                         y: center.y - radius,
                                         width: radius * 2,
                                         height: radius * 2))
        for i in 0..<6 {
            let angle = CGFloat(i) * (.pi / 3)
            let start = CGPoint(x: center.x + cos(angle) * (radius + 6),
                                y: center.y + sin(angle) * (radius + 6))
            let end = CGPoint(x: center.x + cos(angle) * (radius + 16),
                              y: center.y + sin(angle) * (radius + 16))
            context.move(to: start)
            context.addLine(to: end)
        }
        context.strokePath()
    }

    private func drawSoundWaves(in rect: CGRect, context: CGContext) {
        let startX = rect.minX + rect.width * 0.1
        let baseY = rect.minY + rect.height * 0.18
        for i in 0..<3 {
            let radius = rect.width * (0.05 + CGFloat(i) * 0.03)
            let center = CGPoint(x: startX, y: baseY)
            context.addArc(center: center,
                           radius: radius,
                           startAngle: -.pi / 4,
                           endAngle: .pi / 4,
                           clockwise: false)
        }
        context.strokePath()
    }

    private func drawDice(in rect: CGRect, context: CGContext) {
        let size = rect.width * 0.14
        let origin = CGPoint(x: rect.minX + rect.width * 0.12, y: rect.maxY - rect.height * 0.28)
        let dice = CGRect(x: origin.x, y: origin.y, width: size, height: size)
        context.stroke(dice)
        let pipRadius = size * 0.08
        let pips = [
            CGPoint(x: dice.midX, y: dice.midY),
            CGPoint(x: dice.minX + size * 0.25, y: dice.minY + size * 0.25),
            CGPoint(x: dice.maxX - size * 0.25, y: dice.maxY - size * 0.25),
        ]
        for pip in pips {
            context.fillEllipse(in: CGRect(x: pip.x - pipRadius,
                                           y: pip.y - pipRadius,
                                           width: pipRadius * 2,
                                           height: pipRadius * 2))
        }
    }

    private func drawBow(in rect: CGRect, context: CGContext) {
        let headRadius = rect.width * 0.04
        let bodyTop = CGPoint(x: rect.minX + rect.width * 0.18, y: rect.minY + rect.height * 0.35)
        context.strokeEllipse(in: CGRect(x: bodyTop.x - headRadius,
                                         y: bodyTop.y - headRadius * 2,
                                         width: headRadius * 2,
                                         height: headRadius * 2))
        context.move(to: CGPoint(x: bodyTop.x, y: bodyTop.y))
        context.addLine(to: CGPoint(x: bodyTop.x + rect.width * 0.08, y: bodyTop.y + rect.height * 0.12))
        context.strokePath()
    }

    private func drawScale(in rect: CGRect, context: CGContext) {
        let baseY = rect.maxY - rect.height * 0.2
        let centerX = rect.minX + rect.width * 0.18
        context.move(to: CGPoint(x: centerX, y: baseY))
        context.addLine(to: CGPoint(x: centerX, y: baseY - rect.height * 0.18))
        context.strokePath()
        context.move(to: CGPoint(x: centerX - rect.width * 0.08, y: baseY - rect.height * 0.18))
        context.addLine(to: CGPoint(x: centerX + rect.width * 0.1, y: baseY - rect.height * 0.16))
        context.strokePath()
        context.strokeEllipse(in: CGRect(x: centerX - rect.width * 0.12,
                                         y: baseY - rect.height * 0.1,
                                         width: rect.width * 0.08,
                                         height: rect.width * 0.04))
        context.strokeEllipse(in: CGRect(x: centerX + rect.width * 0.06,
                                         y: baseY - rect.height * 0.08,
                                         width: rect.width * 0.08,
                                         height: rect.width * 0.04))
    }

    private func drawOpenHeart(in rect: CGRect, context: CGContext) {
        let center = CGPoint(x: rect.minX + rect.width * 0.18, y: rect.minY + rect.height * 0.22)
        let size = rect.width * 0.07
        let left = CGRect(x: center.x - size, y: center.y - size, width: size, height: size)
        let right = CGRect(x: center.x, y: center.y - size, width: size, height: size)
        context.strokeEllipse(in: left)
        context.strokeEllipse(in: right)
        context.move(to: CGPoint(x: center.x - size, y: center.y))
        context.addLine(to: CGPoint(x: center.x, y: center.y + size * 1.4))
        context.addLine(to: CGPoint(x: center.x + size, y: center.y))
        context.strokePath()
    }

    private func drawHeadacheLines(in rect: CGRect, context: CGContext) {
        let center = CGPoint(x: rect.minX + rect.width * 0.2, y: rect.minY + rect.height * 0.2)
        for i in 0..<3 {
            let offset = CGFloat(i) * 8
            context.move(to: CGPoint(x: center.x - 10, y: center.y + offset))
            context.addLine(to: CGPoint(x: center.x + 10, y: center.y + offset + 6))
        }
        context.strokePath()
    }

    private func drawFlag(in rect: CGRect, context: CGContext) {
        let poleX = rect.minX + rect.width * 0.14
        let topY = rect.minY + rect.height * 0.18
        let bottomY = rect.minY + rect.height * 0.42
        context.move(to: CGPoint(x: poleX, y: bottomY))
        context.addLine(to: CGPoint(x: poleX, y: topY))
        context.strokePath()
        let flagRect = CGRect(x: poleX, y: topY, width: rect.width * 0.14, height: rect.height * 0.1)
        context.stroke(flagRect)
    }

    private func drawMagnifyingGlass(in rect: CGRect, context: CGContext) {
        let radius = rect.width * 0.06
        let center = CGPoint(x: rect.minX + rect.width * 0.18, y: rect.minY + rect.height * 0.24)
        context.strokeEllipse(in: CGRect(x: center.x - radius,
                                         y: center.y - radius,
                                         width: radius * 2,
                                         height: radius * 2))
        context.move(to: CGPoint(x: center.x + radius * 0.7, y: center.y + radius * 0.7))
        context.addLine(to: CGPoint(x: center.x + radius * 1.8, y: center.y + radius * 1.8))
        context.strokePath()
    }

    private func drawHamburger(in rect: CGRect, context: CGContext) {
        let centerX = rect.midX
        let baseY = rect.maxY - rect.height * 0.24
        let width = rect.width * 0.35
        let bunHeight = rect.height * 0.06
        let topBun = CGRect(x: centerX - width / 2, y: baseY - bunHeight * 2, width: width, height: bunHeight)
        let bottomBun = CGRect(x: centerX - width / 2, y: baseY, width: width, height: bunHeight)
        context.stroke(topBun)
        context.stroke(bottomBun)
        context.move(to: CGPoint(x: centerX - width / 2, y: baseY - bunHeight))
        context.addLine(to: CGPoint(x: centerX + width / 2, y: baseY - bunHeight))
        context.strokePath()
    }

    private func drawBird(in rect: CGRect, context: CGContext) {
        let center = CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.3)
        let radius = rect.width * 0.05
        context.addArc(center: center, radius: radius, startAngle: .pi * 0.2, endAngle: .pi * 1.1, clockwise: false)
        context.addArc(center: CGPoint(x: center.x + radius * 1.6, y: center.y),
                       radius: radius,
                       startAngle: .pi * 0.9,
                       endAngle: .pi * 1.8,
                       clockwise: false)
        context.strokePath()
    }
}

extension FlipViewController {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return timeOptionsSec.count
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        let value = timeOptionsSec[row]
        if value == 0 {
            return "0 (時間制限無し)"
        }
        return formatSeconds(value)
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        let value = timeOptionsSec[row]
        selectedTimeSeconds = value
        timeTextField.text = value == 0 ? "0 (時間制限無し)" : formatSeconds(value)
    }

    private func formatSeconds(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        if minutes == 0 {
            return "\(seconds)秒"
        }
        if seconds == 0 {
            return "\(minutes)分"
        }
        return "\(minutes)分\(seconds)秒"
    }
}

private final class StickerDecorView: UIView {
    private let imageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        backgroundColor = .clear
        layer.shadowColor = UIColor.black.withAlphaComponent(0.25).cgColor
        layer.shadowOpacity = 1
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 4

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .clear
        imageView.layer.cornerRadius = 0
        imageView.layer.borderWidth = 0
        imageView.layer.borderColor = UIColor.clear.cgColor
        imageView.clipsToBounds = false
        addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    func setImage(_ image: UIImage?) {
        imageView.image = image
    }
}

private struct SessionQuestion: Codable {
    let index: Int
    let type: String
    let direction: String
    let wordId: String?
    let prompt: String
    let correctAnswer: String
    let userAnswer: String
    let correct: Bool
    let answerTimeSec: Double
}

private struct SessionResult: Codable {
    let timestamp: String
    let reason: String
    let modeLabel: String?
    let directionLabel: String?
    let totalQuestionsGenerated: Int
    let answered: Int
    let score: Int
    let accuracy: Double
    let totalElapsedSec: Double
    let questions: [SessionQuestion]
}

private struct ResultsDatabase: Codable {
    var sessions: [SessionResult]
}


private struct GeminiTextRequest: Encodable {
    struct Content: Encodable {
        struct Part: Encodable {
            let text: String
        }
        let role: String? = nil
        let parts: [Part]
    }
    let contents: [Content]
}

private struct GeminiTextResponse: Decodable {
    struct Candidate: Decodable {
        struct Content: Decodable {
            struct Part: Decodable {
                let text: String?
            }
            let parts: [Part]?
        }
        let content: Content?
    }
    let candidates: [Candidate]?
}
