//
//  TestViewController.swift
//  manki
//
//  Created by 井上　希稟 on 2026/01/15.
//

import UIKit

final class TestViewController: UIViewController, UITextFieldDelegate, UIPickerViewDelegate, UIPickerViewDataSource {

    private enum Direction {
        case enToJa
        case jaToEn
    }

    private struct QuizQuestion {
        let direction: Direction
        let wordId: String
        let prompt: String
        let correctAnswer: String
        let choices: [String]
    }

    private let savedWordsFileName = "saved_words.json"
    private let defaultChoiceCount = 4
    private let resultsFileName = "results.json"

    var presetWords: [SavedWord]?
    private var words: [SavedWord] = []
    private var quiz: [QuizQuestion] = []
    private var currentIndex = 0
    private var score = 0
    private var selectedChoiceIndex: Int?
    private var timer: Timer?
    private var endTime: Date?
    private var questionStartTime: Date?
    private var sessionStartTime: Date?
    private var sessionQuestions: [SessionQuestion] = []
    private var sessionModeLabel: String = ""
    private var sessionDirectionLabel: String = ""

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let settingsStack = UIStackView()
    private let directionSegmented = UISegmentedControl(items: ["英→日", "日→英", "両方"])
    private let numQuestionsTextField = UITextField()
    private let timeTextField = UITextField()
    private let startButton = UIButton(type: .system)
    private let timeLabel = UILabel()
    private let questionLabel = UILabel() //何問目
    private let answerTextField = UITextField()
    private let choicesStack = UIStackView()
    private let favoriteFilterButton = UIButton(type: .system)
    private let submitButton = UIButton(type: .system)
    private let timePicker = UIPickerView() //picker ~
    private let numQuestionsPicker = UIPickerView()

    private let timeOptionsSec = Array(stride(from: 0, through: 600, by: 30))
    private let numQuestionsOptions = Array(stride(from: 0, through: 100, by: 5))
    private var selectedTimeSeconds = 0
    private var favoriteOnly = false
    private var themeObserver: NSObjectProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "テスト"
        view.backgroundColor = .systemBackground

        configureUI()
        configurePickers()
        applyTheme()
        resetQuizUI()
        themeObserver = NotificationCenter.default.addObserver(
            forName: ThemeManager.didChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyTheme()
        }
    }

    private func configureUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        contentStack.axis = .vertical
        contentStack.spacing = AppSpacing.s(16)
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: AppSpacing.s(20)),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: AppSpacing.s(20)),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -AppSpacing.s(20)),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -AppSpacing.s(20)),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -AppSpacing.s(40)),
        ])

        settingsStack.axis = .vertical
        settingsStack.spacing = AppSpacing.s(16)
        contentStack.addArrangedSubview(settingsStack)

        let settingTitle = UILabel()
        settingTitle.text = "テスト設定"
        settingTitle.font = AppFont.jp(size: 18, weight: .regular)
        settingsStack.addArrangedSubview(settingTitle)

        directionSegmented.selectedSegmentIndex = 2
        directionSegmented.setTitleTextAttributes([.font: AppFont.jp(size: 13, weight: .bold)], for: .normal)
        directionSegmented.setTitleTextAttributes([.font: AppFont.jp(size: 13, weight: .bold)], for: .selected)
        settingsStack.addArrangedSubview(directionSegmented)

        configureFilterSection()

        let timeStack = UIStackView()
        timeStack.axis = .vertical
        timeStack.spacing = AppSpacing.s(6)
        let timeLabelTitle = UILabel()
        timeLabelTitle.text = "時間 0=時間制限無し"
        timeLabelTitle.font = AppFont.jp(size: 16, weight: .regular)
        timeTextField.borderStyle = .roundedRect
        timeTextField.font = AppFont.jp(size: 14)
        timeTextField.text = "0"
        timeStack.addArrangedSubview(timeLabelTitle)
        timeStack.addArrangedSubview(timeTextField)
        settingsStack.addArrangedSubview(timeStack)

        let countStack = UIStackView()
        countStack.axis = .vertical
        countStack.spacing = AppSpacing.s(6)
        let numQuestionsTitle = UILabel()
        numQuestionsTitle.text = "問題数 (空 or 0で全問)"
        numQuestionsTitle.font = AppFont.jp(size: 16, weight: .regular)
        numQuestionsTextField.borderStyle = .roundedRect
        numQuestionsTextField.font = AppFont.jp(size: 14)
        numQuestionsTextField.text = "0"
        countStack.addArrangedSubview(numQuestionsTitle)
        countStack.addArrangedSubview(numQuestionsTextField)
        settingsStack.addArrangedSubview(countStack)

        startButton.setTitle("テスト開始", for: .normal)
        startButton.titleLabel?.font = AppFont.jp(size: 16, weight: .bold)
        startButton.addTarget(self, action: #selector(startQuiz), for: .touchUpInside)
        settingsStack.addArrangedSubview(startButton)

        timeLabel.font = AppFont.jp(size: 14, weight: .bold)
        timeLabel.textColor = .secondaryLabel
        contentStack.addArrangedSubview(timeLabel)

        questionLabel.numberOfLines = 0
        questionLabel.font = AppFont.jp(size: 18, weight: .bold)
        contentStack.addArrangedSubview(questionLabel)

        answerTextField.borderStyle = .roundedRect
        answerTextField.placeholder = "回答を入力"
        answerTextField.font = AppFont.jp(size: 16)
        answerTextField.delegate = self
        contentStack.addArrangedSubview(answerTextField)

        choicesStack.axis = .vertical
        choicesStack.spacing = AppSpacing.s(12)
        contentStack.addArrangedSubview(choicesStack)

        submitButton.setTitle("回答する", for: .normal)
        submitButton.titleLabel?.font = AppFont.jp(size: 16, weight: .bold)
        submitButton.addTarget(self, action: #selector(submitAnswer), for: .touchUpInside)
        contentStack.addArrangedSubview(submitButton)
    }

    private func configureFilterSection() {
        let filterTitle = UILabel()
        filterTitle.text = "出題範囲"
        filterTitle.font = AppFont.jp(size: 16, weight: .bold)
        settingsStack.addArrangedSubview(filterTitle)

        let favoriteRow = UIStackView()
        favoriteRow.axis = .horizontal
        favoriteRow.alignment = .center
        favoriteRow.spacing = AppSpacing.s(8)

        favoriteFilterButton.addTarget(self, action: #selector(toggleFavoriteFilter), for: .touchUpInside)
        favoriteFilterButton.tintColor = .systemYellow
        favoriteFilterButton.setTitle(" お気に入りのみ", for: .normal)
        favoriteFilterButton.titleLabel?.font = AppFont.jp(size: 14, weight: .bold)
        favoriteFilterButton.contentHorizontalAlignment = .left
        updateFavoriteFilterButton()

        favoriteRow.addArrangedSubview(favoriteFilterButton)
        settingsStack.addArrangedSubview(favoriteRow)

    }

    private func configurePickers() {
        configurePicker(timePicker, tag: 1, textField: timeTextField, options: timeOptionsSec)
        configurePicker(numQuestionsPicker, tag: 2, textField: numQuestionsTextField, options: numQuestionsOptions)
    }

    private func configurePicker(_ picker: UIPickerView,
                                 tag: Int,
                                 textField: UITextField,
                                 options: [Int]) {
        picker.tag = tag
        picker.delegate = self
        picker.dataSource = self
        textField.inputView = picker
        textField.inputAccessoryView = makeToolbar()
        textField.tintColor = .clear

        let currentValue: Int
        if tag == 1 {
            currentValue = selectedTimeSeconds
        } else {
            currentValue = Int(textField.text ?? "") ?? options.first ?? 0
        }
        if let index = options.firstIndex(of: currentValue) {
            picker.selectRow(index, inComponent: 0, animated: false)
        } else {
            textField.text = "\(options.first ?? 0)"
            picker.selectRow(0, inComponent: 0, animated: false)
        }
        if tag == 1 {
            let value = options[picker.selectedRow(inComponent: 0)]
            selectedTimeSeconds = value
            textField.text = value == 0 ? "0 (時間制限無し)" : formatSeconds(value)
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

    @objc private func startQuiz() {
        words = presetWords ?? loadSavedWords()
        let filteredWords = applyFilters(words: words)
        guard !words.isEmpty else {
            showAlert(title: "単語がありません", message: "先に単語を登録してください。")
            return
        }
        guard !filteredWords.isEmpty else {
            showAlert(title: "条件に合う単語がありません", message: "お気に入り条件を見直してください。")
            return
        }

        let timeLimit = selectedTimeSeconds
        let numQuestionsInput = Int(numQuestionsTextField.text ?? "") ?? 0
        let selectedDirection = directionSegmented.selectedSegmentIndex
        let maxChoices = maxUniqueChoiceCount(for: selectedDirection, words: filteredWords)
        if defaultChoiceCount > maxChoices {
            presentUnifiedModal(
                title: "4択を作れません",
                message: "重複を除くと現在は最大 \(maxChoices) 択までです。",
                actions: [UnifiedModalAction(title: "OK")]
            )
            return
        }
        sessionModeLabel = "4択"
        sessionDirectionLabel = directionLabel(for: selectedDirection)

        quiz = generateQuiz(words: filteredWords,
                            directionIndex: selectedDirection,
                            numQuestions: numQuestionsInput,
                            numChoices: defaultChoiceCount)
        guard !quiz.isEmpty else {
            showAlert(title: "問題を作れません", message: "単語数が不足しています。")
            return
        }

        currentIndex = 0
        score = 0
        selectedChoiceIndex = nil
        sessionQuestions = []
        sessionStartTime = Date()
        startTimerIfNeeded(limitSeconds: timeLimit)
        showQuestion()
    }

    private func generateQuiz(words: [SavedWord],
                              directionIndex: Int,
                              numQuestions: Int,
                              numChoices: Int) -> [QuizQuestion] {
        var questions: [QuizQuestion] = []
        let shuffled = words.shuffled()
        let limit = (numQuestions <= 0) ? shuffled.count : min(numQuestions, shuffled.count)

        for word in shuffled.prefix(limit) {
            let direction: Direction
            if directionIndex == 0 {
                direction = .enToJa
            } else if directionIndex == 1 {
                direction = .jaToEn
            } else {
                direction = Bool.random() ? .enToJa : .jaToEn
            }

            if words.count < 2 {
                continue
            }

            let question = buildQuestion(word: word,
                                         words: words,
                                         direction: direction,
                                         numChoices: numChoices)
            questions.append(question)
        }
        return questions
    }

    private func maxUniqueChoiceCount(for directionIndex: Int, words: [SavedWord]) -> Int {
        let uniqueJP = Set(words.map { $0.japanese }).count
        let uniqueEN = Set(words.map { $0.english }).count
        switch directionIndex {
        case 0:
            return uniqueJP
        case 1:
            return uniqueEN
        default:
            return min(uniqueJP, uniqueEN)
        }
    }

    private func buildQuestion(word: SavedWord,
                               words: [SavedWord],
                               direction: Direction,
                               numChoices: Int) -> QuizQuestion {
        let prompt: String
        let correct: String

        switch direction {
        case .enToJa:
            prompt = "「\(word.english)」の意味を答えてください。"
            correct = word.japanese
        case .jaToEn:
            prompt = "「\(word.japanese)」に合う英単語を答えてください。"
            correct = word.english
        }

        let choices = buildChoices(correctWord: word,
                                   words: words,
                                   direction: direction,
                                   numChoices: numChoices)
        return QuizQuestion(direction: direction,
                            wordId: word.id,
                            prompt: prompt,
                            correctAnswer: correct,
                            choices: choices)
    }

    private func buildChoices(correctWord: SavedWord,
                              words: [SavedWord],
                              direction: Direction,
                              numChoices: Int) -> [String] {
        let others = words.filter { $0.english != correctWord.english || $0.japanese != correctWord.japanese }
        var pool = others.shuffled()
        var choices: [String] = []

        let correctChoice = (direction == .enToJa) ? correctWord.japanese : correctWord.english
        choices.append(correctChoice)

        let limit = max(2, min(numChoices, words.count))
        while choices.count < limit && !pool.isEmpty {
            let candidate = pool.removeFirst()
            let value = (direction == .enToJa) ? candidate.japanese : candidate.english
            if !choices.contains(value) {
                choices.append(value)
            }
        }

        choices.shuffle()
        return choices
    }

    private func showQuestion() {
        guard currentIndex < quiz.count else {
            finishQuiz(reason: "完了")
            return
        }

        settingsStack.isHidden = true
        let question = quiz[currentIndex]
        questionLabel.text = "Q\(currentIndex + 1)/Q\(quiz.count)  \(question.prompt)"
        answerTextField.text = ""
        selectedChoiceIndex = nil

        answerTextField.isHidden = true
        choicesStack.isHidden = false
        configureChoiceButtons(choices: question.choices)

        questionStartTime = Date()
        submitButton.isHidden = false
        startButton.isEnabled = false
    }

    private func configureChoiceButtons(choices: [String]) {
        clearChoices()
        for (index, text) in choices.enumerated() {
            let button = UIButton(type: .system)
            button.setTitle(text, for: .normal)
            button.titleLabel?.font = AppFont.jp(size: 16, weight: .regular)
            button.contentHorizontalAlignment = .left
            if var configuration = button.configuration {
                configuration.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
                button.configuration = configuration
            } else {
                button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
            }
            button.layer.borderWidth = 1
            button.layer.cornerRadius = 8
            button.layer.borderColor = UIColor.systemGray4.cgColor
            button.tag = index
            button.addTarget(self, action: #selector(choiceTapped(_:)), for: .touchUpInside)
            styleChoiceButton(button, selected: false)
            choicesStack.addArrangedSubview(button)
        }
    }

    private func clearChoices() {
        choicesStack.arrangedSubviews.forEach { view in
            choicesStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
    }

    @objc private func choiceTapped(_ sender: UIButton) {
        selectedChoiceIndex = sender.tag
        for case let button as UIButton in choicesStack.arrangedSubviews {
            let isSelected = button.tag == sender.tag
            styleChoiceButton(button, selected: isSelected)
        }
    }

    @objc private func submitAnswer() {
        guard currentIndex < quiz.count else { return }
        let question = quiz[currentIndex]

        let userAnswer: String
        guard let selected = selectedChoiceIndex,
              selected < question.choices.count else {
            showAlert(title: "選択してください", message: "選択肢を1つ選んでください。")
            return
        }
        userAnswer = question.choices[selected]

        if normalize(userAnswer) == normalize(question.correctAnswer) {
            score += 1
        }

        let answerTime = Date().timeIntervalSince(questionStartTime ?? Date())
        recordSessionQuestion(question: question,
                              userAnswer: userAnswer,
                              correct: normalize(userAnswer) == normalize(question.correctAnswer),
                              answerTime: answerTime)

        currentIndex += 1
        showQuestion()
    }

    private func normalize(_ text: String) -> String {
        return text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func applyFilters(words: [SavedWord]) -> [SavedWord] {
        var filtered = words
        if favoriteOnly {
            filtered = filtered.filter { $0.isFavorite }
        }
        return filtered
    }

    @objc private func toggleFavoriteFilter() {
        favoriteOnly.toggle()
        updateFavoriteFilterButton()
    }

    private func updateFavoriteFilterButton() {
        let imageName = favoriteOnly ? "star.fill" : "star"
        favoriteFilterButton.setImage(UIImage(systemName: imageName), for: .normal)
        ThemeManager.styleSecondaryButton(favoriteFilterButton)
    }

    private func applyTheme() {
        let palette = ThemeManager.palette()
        ThemeManager.applyBackground(to: view)
        ThemeManager.applyNavigationAppearance(to: navigationController)
        scrollView.backgroundColor = .clear
        contentStack.backgroundColor = .clear
        directionSegmented.selectedSegmentTintColor = palette.accent
        directionSegmented.backgroundColor = palette.surface
        directionSegmented.setTitleTextAttributes([
            .font: AppFont.jp(size: 13, weight: .bold),
            .foregroundColor: palette.text
        ], for: .normal)
        directionSegmented.setTitleTextAttributes([
            .font: AppFont.jp(size: 13, weight: .bold),
            .foregroundColor: palette.text
        ], for: .selected)
        [numQuestionsTextField, timeTextField, answerTextField].forEach { textField in
            textField.backgroundColor = palette.surface
            textField.textColor = palette.text
            textField.layer.cornerRadius = 10
            textField.layer.borderWidth = 1
            textField.layer.borderColor = palette.border.cgColor
        }
        timeLabel.textColor = palette.mutedText
        questionLabel.textColor = palette.text
        ThemeManager.stylePrimaryButton(startButton)
        ThemeManager.stylePrimaryButton(submitButton)
        ThemeManager.styleSecondaryButton(favoriteFilterButton)
        for case let button as UIButton in choicesStack.arrangedSubviews {
            styleChoiceButton(button, selected: selectedChoiceIndex == button.tag)
        }
    }

    private func styleChoiceButton(_ button: UIButton, selected: Bool) {
        let palette = ThemeManager.palette()
        button.configuration = nil
        button.backgroundColor = selected ? palette.surfaceAlt : palette.surface
        button.setTitleColor(palette.text, for: .normal)
        button.setTitleColor(palette.text.withAlphaComponent(0.72), for: .highlighted)
        button.titleLabel?.font = AppFont.jp(size: 16, weight: selected ? .bold : .regular)
        button.layer.borderWidth = selected ? 2 : 1
        button.layer.cornerRadius = 8
        button.layer.borderColor = (selected ? palette.accentStrong : palette.border).cgColor
    }

    private func startTimerIfNeeded(limitSeconds: Int) {
        timer?.invalidate()
        timeLabel.text = ""
        endTime = nil

        guard limitSeconds > 0 else { return }

        endTime = Date().addingTimeInterval(TimeInterval(limitSeconds))
        updateRemainingTime()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateRemainingTime()
        }
    }

    private func updateRemainingTime() {
        guard let endTime else { return }
        let remaining = Int(endTime.timeIntervalSinceNow.rounded(.down))
        if remaining <= 0 {
            timeLabel.text = "残り時間: 0秒"
            finishQuiz(reason: "時間切れ")
            return
        }
        timeLabel.text = "残り時間: \(remaining)秒"
    }

    private func finishQuiz(reason: String) {
        timer?.invalidate()
        timer = nil
        let answered = min(currentIndex, quiz.count)
        let accuracy = answered > 0 ? Double(score) / Double(answered) : 0
        saveSession(reason: reason)

        let message = """
        \(reason)
        スコア: \(score)/\(answered)
        正答率: \(String(format: "%.1f", accuracy * 100))%
        """

        showAlert(title: "テスト結果", message: message) { [weak self] in
            self?.resetQuizUI()
        }
    }

    private func resetQuizUI() {
        questionLabel.text = "テスト設定を選んで開始してください。"
        timeLabel.text = ""
        answerTextField.text = ""
        answerTextField.isHidden = true
        clearChoices()
        choicesStack.isHidden = true
        submitButton.isHidden = true
        startButton.isEnabled = true
        settingsStack.isHidden = false
        sessionStartTime = nil
        questionStartTime = nil
    }

    private func showAlert(title: String, message: String, onOK: (() -> Void)? = nil) {
        presentUnifiedModal(
            title: title,
            message: message,
            actions: [UnifiedModalAction(title: "OK", handler: onOK)]
        )
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        submitAnswer()
        return true
    }

    private func recordSessionQuestion(question: QuizQuestion,
                                       userAnswer: String,
                                       correct: Bool,
                                       answerTime: TimeInterval) {
        let entry = SessionQuestion(
            index: currentIndex + 1,
            type: "choice",
            direction: question.direction == .enToJa ? "en_to_ja" : "ja_to_en",
            wordId: question.wordId,
            prompt: question.prompt,
            correctAnswer: question.correctAnswer,
            userAnswer: userAnswer,
            correct: correct,
            answerTimeSec: round(answerTime * 1000) / 1000
        )
        sessionQuestions.append(entry)
    }

    private func saveSession(reason: String) {
        guard let sessionStartTime else { return }
        let modeLabel = sessionModeLabel.isEmpty ? "不明" : sessionModeLabel
        let directionLabel = sessionDirectionLabel.isEmpty ? "不明" : sessionDirectionLabel
        let session = SessionResult(
            timestamp: isoTimestamp(),
            reason: reason,
            modeLabel: modeLabel,
            directionLabel: directionLabel,
            totalQuestionsGenerated: quiz.count,
            answered: sessionQuestions.count,
            score: score,
            accuracy: sessionQuestions.isEmpty ? 0 : Double(score) / Double(sessionQuestions.count),
            totalElapsedSec: Date().timeIntervalSince(sessionStartTime),
            questions: sessionQuestions
        )

        var db = loadResults()
        db.sessions.append(session)
        saveResults(db)
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

    private func directionLabel(for index: Int) -> String {
        switch index {
        case 0:
            return "英→日"
        case 1:
            return "日→英"
        default:
            return "混合"
        }
    }

    deinit {
        if let observer = themeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

extension TestViewController {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return options(for: pickerView).count
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        let value = options(for: pickerView)[row]
        if pickerView.tag == 1 && value == 0 {
            return "0 (時間制限無し)"
        }
        if pickerView.tag == 1 {
            return formatSeconds(value)
        }
        return "\(value)"
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        let value = options(for: pickerView)[row]
        switch pickerView.tag {
        case 1:
            selectedTimeSeconds = value
            timeTextField.text = value == 0 ? "0 (時間制限無し)" : formatSeconds(value)
        case 2:
            numQuestionsTextField.text = "\(value)"
        default:
            break
        }
    }

    private func options(for pickerView: UIPickerView) -> [Int] {
        switch pickerView.tag {
        case 1:
            return timeOptionsSec
        case 2:
            return numQuestionsOptions
        default:
            return []
        }
    }

    private func formatSeconds(_ totalSeconds: Int) -> String { //時間のpickerで何分何秒を表示する処理
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60 //何秒
        if minutes == 0 {
            return "\(seconds)秒"
        }
        if seconds == 0 { //秒数が0の時に何分で表示
            return "\(minutes)分"
        }
        return "\(minutes)分\(seconds)秒"
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
