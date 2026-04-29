//
//  ResultViewController.swift
//  manki
//
//  Created by 井上　希稟 on 2026/01/15.
//

import UIKit

final class ResultViewController: BaseViewController {

    private let resultsFileName = "results.json"
    private let textView = UITextView()
    private let filterControl = UISegmentedControl(items: ["今日", "1週間", "1ヶ月"])
    private var sessions: [SessionResult] = []

    private enum FilterRange: Int {
        case today = 0
        case week = 1
        case month = 2
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "結果"

        configureUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadResults()
    }

    private func configureUI() {
        filterControl.selectedSegmentIndex = FilterRange.today.rawValue
        filterControl.addTarget(self, action: #selector(filterChanged), for: .valueChanged)
        filterControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(filterControl)

        textView.isEditable = false
        textView.font = AppFont.jp(size: 14)
        textView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(textView)

        NSLayoutConstraint.activate([
            filterControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: AppSpacing.s(12)),
            filterControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AppSpacing.s(12)),
            filterControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AppSpacing.s(12)),
            textView.topAnchor.constraint(equalTo: filterControl.bottomAnchor, constant: AppSpacing.s(12)),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AppSpacing.s(12)),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AppSpacing.s(12)),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -AppSpacing.s(12)),
        ])
    }

    private func resultsFileURL() -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory,
                                                 in: .userDomainMask).first!
        return documents.appendingPathComponent(resultsFileName)
    }

    private func reloadResults() {
        let url = resultsFileURL()
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(ResultsDatabase.self, from: data) else {
            textView.text = "まだ結果がありません。"
            return
        }

        if decoded.sessions.isEmpty {
            textView.text = "まだ結果がありません。"
            return
        }

        sessions = decoded.sessions
        applyFilter()
    }

    @objc private func filterChanged() {
        applyFilter()
    }

    private func applyFilter() {
        guard let range = FilterRange(rawValue: filterControl.selectedSegmentIndex) else {
            textView.attributedText = formatResultsAttributed(sessions)
            return
        }
        let filtered = filterSessions(sessions, range: range)
        if filtered.isEmpty {
            textView.text = "指定期間の結果がありません。"
        } else {
            textView.attributedText = formatResultsAttributed(filtered)
        }
    }

    private func filterSessions(_ sessions: [SessionResult], range: FilterRange) -> [SessionResult] {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let start: Date
        switch range {
        case .today:
            start = startOfToday
        case .week:
            start = calendar.date(byAdding: .day, value: -6, to: startOfToday) ?? startOfToday
        case .month:
            start = calendar.date(byAdding: .day, value: -29, to: startOfToday) ?? startOfToday
        }
        let end = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now

        return sessions.filter { session in
            guard let date = parseTimestamp(session.timestamp) else {
                return true
            }
            if range == .today {
                return date >= start && date < end
            }
            return date >= start && date <= now
        }
    }

    private func parseTimestamp(_ text: String) -> Date? {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: text) {
            return date
        }
        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]
        return fallback.date(from: text)
    }

    private func formatResultsAttributed(_ sessions: [SessionResult]) -> NSAttributedString {
        let palette = ThemeManager.palette()
        let baseFont = AppFont.jp(size: 14)
        let boldFont = AppFont.jp(size: 14, weight: .bold)
        let baseColor = palette.text
        let redColor = UIColor.systemRed

        let result = NSMutableAttributedString()

        func append(_ text: String, font: UIFont = baseFont, color: UIColor = baseColor) {
            result.append(NSAttributedString(string: text, attributes: [
                .font: font,
                .foregroundColor: color
            ]))
        }

        for (index, session) in sessions.enumerated().reversed() {
            append("=== セッション \(sessions.count - index) ===\n", font: boldFont)
            append("日時: \(session.timestamp)\n")
            append("理由: \(session.reason)\n")
            let modeLabel = session.modeLabel ?? "不明"
            let directionLabel = session.directionLabel ?? "不明"
            append("モード: \(modeLabel) / \(directionLabel)\n")
            append("スコア: \(session.score)/\(session.answered)\n")
            append(String(format: "正答率: %.1f%%\n", session.accuracy * 100))
            append(String(format: "合計時間: %.2fs\n", session.totalElapsedSec))
            append("---- 問題 ----\n", font: boldFont)

            if session.questions.isEmpty {
                append("問題の詳細がありません。\n\n")
                continue
            }

            for question in session.questions {
                let isCorrect = question.correct
                let color = isCorrect ? baseColor : redColor
                let resultText = isCorrect ? "正解" : "不正解"
                append("Q\(question.index)（\(question.type) / \(question.direction)）\n",
                       font: boldFont,
                       color: color)
                append("質問: \(question.prompt)\n", color: color)
                append("あなたの回答: \(question.userAnswer)（\(resultText)）\n", color: color)
                append("正解: \(question.correctAnswer)\n", color: color)
                append(String(format: "解答時間: %.2fs\n\n", question.answerTimeSec), color: color)
            }
            append("\n")
        }

        return result
    }

    override func applyBaseTheme() {
        super.applyBaseTheme()
        let palette = ThemeManager.palette()
        textView.backgroundColor = palette.surface.withAlphaComponent(0.94)
        textView.textColor = palette.text
        textView.layer.cornerRadius = 18
        textView.layer.borderWidth = 2
        textView.layer.borderColor = palette.border.cgColor
        filterControl.backgroundColor = palette.surface.withAlphaComponent(0.96)
        filterControl.selectedSegmentTintColor = palette.accent
        filterControl.setTitleTextAttributes([
            .font: AppFont.jp(size: 13, weight: .bold),
            .foregroundColor: palette.text
        ], for: .normal)
        filterControl.setTitleTextAttributes([
            .font: AppFont.jp(size: 13, weight: .bold),
            .foregroundColor: palette.text
        ], for: .selected)
    }
}

private struct SessionQuestion: Codable {
    let index: Int
    let type: String
    let direction: String
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
    let sessions: [SessionResult]
}
