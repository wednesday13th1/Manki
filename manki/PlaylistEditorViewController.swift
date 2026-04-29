import UIKit

final class PlaylistEditorViewController: BaseViewController {
    enum Mode {
        case playlist
        case song
        case card(sourceSongTitle: String)

        var screenTitle: String {
            switch self {
            case .playlist:
                return "Playlist作成"
            case .song:
                return "曲を追加"
            case .card:
                return "カードを追加"
            }
        }
    }

    private let mode: Mode
    private let onSavePlaylist: ((Playlist) -> Void)?
    private let onSaveSong: ((PlaylistSong) -> Void)?
    private let onSaveCard: ((PlaylistCard) -> Void)?

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private let titleLabel = UILabel()
    private let noteLabel = UILabel()
    private let saveButton = UIButton(type: .system)

    private let titleField = UITextField()
    private let descriptionView = UITextView()
    private let artistField = UITextField()
    private let wordField = UITextField()
    private let meaningField = UITextField()
    private let exampleField = UITextField()
    private let memoView = UITextView()
    private let emotionThemeButton = UIButton(type: .system)
    private let emotionTagButton = UIButton(type: .system)
    private let difficultyButton = UIButton(type: .system)

    private var selectedTheme: EmotionTag = .sad
    private var selectedCardEmotion: EmotionTag = .sad
    private var selectedDifficulty: PlaylistCardDifficulty = .easy

    init(onSavePlaylist: @escaping (Playlist) -> Void) {
        mode = .playlist
        self.onSavePlaylist = onSavePlaylist
        self.onSaveSong = nil
        self.onSaveCard = nil
        super.init(nibName: nil, bundle: nil)
    }

    init(onSaveSong: @escaping (PlaylistSong) -> Void) {
        mode = .song
        self.onSavePlaylist = nil
        self.onSaveSong = onSaveSong
        self.onSaveCard = nil
        super.init(nibName: nil, bundle: nil)
    }

    init(sourceSongTitle: String, onSaveCard: @escaping (PlaylistCard) -> Void) {
        mode = .card(sourceSongTitle: sourceSongTitle)
        self.onSavePlaylist = nil
        self.onSaveSong = nil
        self.onSaveCard = onSaveCard
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = mode.screenTitle
        configureUI()
        applyTheme()
    }

    override func applyBaseTheme() {
        super.applyBaseTheme()
        applyTheme()
    }

    private func configureUI() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "保存",
            style: .plain,
            target: self,
            action: #selector(saveTapped)
        )

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = AppSpacing.s(16)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        noteLabel.translatesAutoresizingMaskIntoConstraints = false
        noteLabel.numberOfLines = 0

        descriptionView.translatesAutoresizingMaskIntoConstraints = false
        memoView.translatesAutoresizingMaskIntoConstraints = false
        descriptionView.heightAnchor.constraint(equalToConstant: 110).isActive = true
        memoView.heightAnchor.constraint(equalToConstant: 110).isActive = true

        view.addSubview(scrollView)
        scrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: AppSpacing.s(18)),
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: AppSpacing.s(20)),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -AppSpacing.s(20)),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -AppSpacing.s(24)),
            stackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -AppSpacing.s(40))
        ])

        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(noteLabel)

        switch mode {
        case .playlist:
            stackView.addArrangedSubview(makeFieldBlock(title: "タイトル", field: titleField, placeholder: "Heartbreak Words"))
            stackView.addArrangedSubview(makeTextViewBlock(title: "説明", textView: descriptionView, placeholder: "気分や曲のイメージを書く"))
            stackView.addArrangedSubview(makeSelectionBlock(title: "感情テーマ", button: emotionThemeButton, action: #selector(selectThemeEmotion)))
        case .song:
            stackView.addArrangedSubview(makeFieldBlock(title: "曲名", field: titleField, placeholder: "Sample Song"))
            stackView.addArrangedSubview(makeFieldBlock(title: "アーティスト", field: artistField, placeholder: "Sample Artist"))
        case .card(let sourceSongTitle):
            stackView.addArrangedSubview(makeFieldBlock(title: "word", field: wordField, placeholder: "lonely"))
            stackView.addArrangedSubview(makeFieldBlock(title: "meaning", field: meaningField, placeholder: "孤独な"))
            stackView.addArrangedSubview(makeFieldBlock(title: "examplePhrase", field: exampleField, placeholder: "I feel lonely tonight."))
            stackView.addArrangedSubview(makeSelectionBlock(title: "emotionTag", button: emotionTagButton, action: #selector(selectCardEmotion)))
            stackView.addArrangedSubview(makeSelectionBlock(title: "difficulty", button: difficultyButton, action: #selector(selectDifficulty)))
            stackView.addArrangedSubview(makeTextViewBlock(title: "memo", textView: memoView, placeholder: "サビの雰囲気と一緒に覚える"))

            let sourceLabel = UILabel()
            sourceLabel.applyMankiTextStyle(.caption, color: ThemeManager.palette().mutedText, numberOfLines: 0)
            sourceLabel.text = "sourceSongTitle: \(sourceSongTitle)"
            stackView.addArrangedSubview(sourceLabel)
        }

        saveButton.setTitle("保存する", for: .normal)
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        stackView.addArrangedSubview(saveButton)

        descriptionView.text = "気分や曲のイメージを書く"
        memoView.text = "サビや雰囲気のメモを書く"
        updateSelectionTitles()
    }

    private func makeFieldBlock(title: String, field: UITextField, placeholder: String) -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = AppSpacing.s(8)

        let label = UILabel()
        label.text = title
        container.addArrangedSubview(label)

        field.placeholder = placeholder
        field.borderStyle = .none
        field.layer.cornerRadius = 16
        field.layer.borderWidth = 2
        field.setLeftPadding(12)
        field.heightAnchor.constraint(equalToConstant: 52).isActive = true
        container.addArrangedSubview(field)
        return container
    }

    private func makeTextViewBlock(title: String, textView: UITextView, placeholder: String) -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = AppSpacing.s(8)

        let label = UILabel()
        label.text = title
        container.addArrangedSubview(label)

        textView.layer.cornerRadius = 16
        textView.layer.borderWidth = 2
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 10, bottom: 12, right: 10)
        textView.text = placeholder
        container.addArrangedSubview(textView)
        return container
    }

    private func makeSelectionBlock(title: String, button: UIButton, action: Selector) -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = AppSpacing.s(8)

        let label = UILabel()
        label.text = title
        container.addArrangedSubview(label)

        button.addTarget(self, action: action, for: .touchUpInside)
        container.addArrangedSubview(button)
        return container
    }

    private func applyTheme() {
        let palette = ThemeManager.palette()
        titleLabel.applyMankiTextStyle(.screenTitle, color: palette.text, numberOfLines: 0)
        titleLabel.text = mode.screenTitle
        noteLabel.applyMankiTextStyle(.caption, color: palette.mutedText, numberOfLines: 0)
        noteLabel.text = "歌詞全文は保存せず、短いオリジナル例文や自分用メモだけを記録します。"

        let labels = stackView.arrangedSubviews.compactMap { view -> UILabel? in
            if let stack = view as? UIStackView {
                return stack.arrangedSubviews.first as? UILabel
            }
            return view as? UILabel
        }
        labels.forEach { label in
            if label !== titleLabel && label !== noteLabel {
                label.applyMankiTextStyle(.sectionTitle, color: palette.text, numberOfLines: 1)
            }
        }

        [descriptionView, memoView].forEach { textView in
            textView.font = AppFont.jp(size: 15)
            textView.textColor = palette.text
            textView.backgroundColor = palette.surface.withAlphaComponent(0.96)
            textView.layer.borderColor = palette.border.cgColor
        }

        [titleField, artistField, wordField, meaningField, exampleField].forEach { field in
            field.font = AppFont.jp(size: 15)
            field.textColor = palette.text
            field.backgroundColor = palette.surface.withAlphaComponent(0.96)
            field.layer.borderColor = palette.border.cgColor
        }

        [emotionThemeButton, emotionTagButton, difficultyButton].forEach {
            ThemeManager.styleSecondaryButton($0)
        }
        ThemeManager.stylePrimaryButton(saveButton)
        updateSelectionTitles()
    }

    private func updateSelectionTitles() {
        emotionThemeButton.setTitle("テーマ: \(selectedTheme.displayName)", for: .normal)
        emotionTagButton.setTitle("タグ: \(selectedCardEmotion.displayName)", for: .normal)
        difficultyButton.setTitle("難易度: \(selectedDifficulty.displayName)", for: .normal)
    }

    @objc private func selectThemeEmotion() {
        presentEmotionPicker(current: selectedTheme) { [weak self] tag in
            self?.selectedTheme = tag
            self?.updateSelectionTitles()
        }
    }

    @objc private func selectCardEmotion() {
        presentEmotionPicker(current: selectedCardEmotion) { [weak self] tag in
            self?.selectedCardEmotion = tag
            self?.updateSelectionTitles()
        }
    }

    @objc private func selectDifficulty() {
        let actions = PlaylistCardDifficulty.allCases.map { difficulty in
            UnifiedModalAction(title: difficulty.displayName) { [weak self] in
                self?.selectedDifficulty = difficulty
                self?.updateSelectionTitles()
            }
        } + [UnifiedModalAction(title: "キャンセル", style: .cancel)]
        presentUnifiedModal(title: "難易度を選ぶ", message: nil, actions: actions)
    }

    private func presentEmotionPicker(current: EmotionTag, onSelect: @escaping (EmotionTag) -> Void) {
        let actions = EmotionTag.allCases.map { tag in
            UnifiedModalAction(title: tag == current ? "\(tag.displayName) ✓" : tag.displayName) {
                onSelect(tag)
            }
        } + [UnifiedModalAction(title: "キャンセル", style: .cancel)]
        presentUnifiedModal(title: "感情タグを選ぶ", message: nil, actions: actions)
    }

    @objc private func saveTapped() {
        switch mode {
        case .playlist:
            let title = titleField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !title.isEmpty else {
                showValidationError(message: "Playlist タイトルを入力してください。")
                return
            }
            let description = sanitizedText(from: descriptionView, placeholder: "気分や曲のイメージを書く")
            onSavePlaylist?(Playlist(title: title, description: description, emotionTheme: selectedTheme))
        case .song:
            let title = titleField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !title.isEmpty else {
                showValidationError(message: "曲名を入力してください。")
                return
            }
            let artist = artistField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown Artist"
            onSaveSong?(PlaylistSong(title: title, artist: artist))
        case .card(let sourceSongTitle):
            let word = wordField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let meaning = meaningField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !word.isEmpty, !meaning.isEmpty else {
                showValidationError(message: "word と meaning は必須です。")
                return
            }
            let example = exampleField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let memo = sanitizedText(from: memoView, placeholder: "サビや雰囲気のメモを書く")
            onSaveCard?(PlaylistCard(
                word: word,
                meaning: meaning,
                examplePhrase: example,
                sourceSongTitle: sourceSongTitle,
                emotionTag: selectedCardEmotion,
                difficulty: selectedDifficulty,
                memo: memo
            ))
        }
        navigationController?.popViewController(animated: true)
    }

    private func sanitizedText(from textView: UITextView, placeholder: String) -> String {
        let text = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return text == placeholder ? "" : text
    }

    private func showValidationError(message: String) {
        presentUnifiedModal(title: "入力を確認", message: message, actions: [UnifiedModalAction(title: "OK")])
    }
}

private extension UITextField {
    func setLeftPadding(_ amount: CGFloat) {
        let padding = UIView(frame: CGRect(x: 0, y: 0, width: amount, height: 1))
        leftView = padding
        leftViewMode = .always
    }
}
