//
//  QuizViewController.swift
//  manki
//
//  Created by 井上　希稟 on 2026/01/15.
//

import UIKit

final class QuizViewController: UIViewController {

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let contentColumn = UIStackView()
    private let heroCard = UIView()
    private let heroStack = UIStackView()
    private let heroIconLabel = UILabel()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let noteLabel = UILabel()
    private let actionStack = UIStackView()
    private let startTestButton = UIButton(type: .system)
    private let resultsButton = UIButton(type: .system)
    private let footerLabel = UILabel()
    private var contentLeadingConstraint: NSLayoutConstraint?
    private var contentTrailingConstraint: NSLayoutConstraint?
    private var contentWidthConstraint: NSLayoutConstraint?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "クイズ"

        configureUI()
        applyTheme()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateLayoutMetrics()
    }

    private func configureUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive
        view.addSubview(scrollView)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        contentColumn.axis = .vertical
        contentColumn.spacing = AppLayout.sectionSpacing
        contentColumn.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(contentColumn)

        NSLayoutConstraint.activate([
            scrollView.frameLayoutGuide.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.frameLayoutGuide.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.frameLayoutGuide.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.frameLayoutGuide.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            contentColumn.topAnchor.constraint(equalTo: contentView.topAnchor, constant: AppLayout.contentVerticalInset),
            contentColumn.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -AppLayout.contentVerticalInset),
            contentColumn.centerXAnchor.constraint(equalTo: contentView.centerXAnchor)
        ])

        contentLeadingConstraint = contentColumn.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AppLayout.horizontalInset(for: view.bounds.width))
        contentTrailingConstraint = contentColumn.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -AppLayout.horizontalInset(for: view.bounds.width))
        contentWidthConstraint = contentColumn.widthAnchor.constraint(lessThanOrEqualToConstant: AppLayout.maxContentWidth)
        NSLayoutConstraint.activate([
            contentLeadingConstraint,
            contentTrailingConstraint,
            contentWidthConstraint
        ].compactMap { $0 })

        configureHeroCard()
        configureActionButtons()
        configureFooter()
    }

    private func configureHeroCard() {
        heroStack.axis = .vertical
        heroStack.spacing = AppSpacing.s(10)
        heroStack.translatesAutoresizingMaskIntoConstraints = false
        heroCard.addSubview(heroStack)

        heroIconLabel.text = "🎮"
        heroIconLabel.textAlignment = .center
        heroIconLabel.font = UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: AppFont.jp(size: AppSpacing.s(32), weight: .bold))
        heroIconLabel.adjustsFontForContentSizeCategory = true

        titleLabel.text = "クイズメニュー"
        subtitleLabel.text = "小さい画面では縦に収まり、大きい画面では横に広がりすぎない幅で表示します。"
        noteLabel.text = "英単語・日本語が長くても複数行で崩れにくい構造です。"

        heroStack.addArrangedSubview(heroIconLabel)
        heroStack.addArrangedSubview(titleLabel)
        heroStack.addArrangedSubview(subtitleLabel)
        heroStack.addArrangedSubview(noteLabel)
        contentColumn.addArrangedSubview(heroCard)

        NSLayoutConstraint.activate([
            heroStack.topAnchor.constraint(equalTo: heroCard.topAnchor),
            heroStack.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor),
            heroStack.trailingAnchor.constraint(equalTo: heroCard.trailingAnchor),
            heroStack.bottomAnchor.constraint(equalTo: heroCard.bottomAnchor),
            heroCard.heightAnchor.constraint(greaterThanOrEqualToConstant: AppLayout.minCardHeight)
        ])
    }

    private func configureActionButtons() {
        actionStack.axis = .vertical
        actionStack.spacing = AppSpacing.s(12)
        actionStack.translatesAutoresizingMaskIntoConstraints = false

        startTestButton.setTitle("テスト開始", for: .normal)
        startTestButton.addTarget(self, action: #selector(openTest), for: .touchUpInside)

        resultsButton.setTitle("結果を見る", for: .normal)
        resultsButton.addTarget(self, action: #selector(openResults), for: .touchUpInside)

        [startTestButton, resultsButton].forEach { button in
            actionStack.addArrangedSubview(button)
        }

        contentColumn.addArrangedSubview(actionStack)
    }

    private func configureFooter() {
        footerLabel.text = "今後ボタンが増えても、`contentColumn` にカードやセクションを足すだけで画面構造を保てます。"
        footerLabel.textAlignment = .center
        contentColumn.addArrangedSubview(footerLabel)
    }

    private func applyTheme() {
        let palette = ThemeManager.palette()
        ThemeManager.applyBackground(to: view)
        ThemeManager.applyNavigationAppearance(to: navigationController)

        ThemeManager.styleCard(heroCard, fillColor: palette.surfaceAlt)

        titleLabel.applyMankiTextStyle(.screenTitle, color: palette.text, alignment: .center)
        subtitleLabel.applyMankiTextStyle(.body, color: palette.text, alignment: .center)
        noteLabel.applyMankiTextStyle(.caption, color: palette.mutedText, alignment: .center)
        footerLabel.applyMankiTextStyle(.caption, color: palette.mutedText, alignment: .center)

        ThemeManager.stylePrimaryButton(startTestButton)
        ThemeManager.styleSecondaryButton(resultsButton)
    }

    private func updateLayoutMetrics() {
        let width = view.bounds.width
        let inset = AppLayout.horizontalInset(for: width)
        let cardPadding = AppLayout.cardInnerPadding(for: width)
        contentLeadingConstraint?.constant = inset
        contentTrailingConstraint?.constant = -inset
        contentWidthConstraint?.constant = min(AppLayout.maxContentWidth, width - (inset * 2))
        heroStack.layoutMargins = UIEdgeInsets(top: cardPadding, left: cardPadding, bottom: cardPadding, right: cardPadding)
        heroStack.isLayoutMarginsRelativeArrangement = true
    }

    @objc private func openTest() {
        let controller = TestViewController()
        navigationController?.pushViewController(controller, animated: true)
    }

    @objc private func openResults() {
        let controller = ResultViewController()
        navigationController?.pushViewController(controller, animated: true)
    }
}
