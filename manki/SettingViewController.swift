//
//  SettingViewController.swift
//  manki
//
//  Created by 井上　希稟 on 2026/01/25.
//

import UIKit
import PhotosUI

class SettingViewController: UIViewController, PHPickerViewControllerDelegate {

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let themeTitleLabel = UILabel()
    private let backgroundTitleLabel = UILabel()
    private let opacityTitleLabel = UILabel()
    private let opacityValueLabel = UILabel()
    private let tintTitleLabel = UILabel()
    private let tintValueLabel = UILabel()
    private let textSizeTitleLabel = UILabel()
    private let textSizeValueLabel = UILabel()
    private let readabilityTitleLabel = UILabel()
    private let readabilityValueLabel = UILabel()
    private let themeStack = UIStackView()
    private let backgroundButton = UIButton(type: .system)
    private let opacitySlider = UISlider()
    private let tintSlider = UISlider()
    private let textSizeSegmented = UISegmentedControl(items: AppTextSize.allCases.map { $0.displayName })
    private let readabilitySlider = UISlider()
    private var themeButtons: [UIButton] = []
    private let cardView = UIView()
    private var themeObserver: NSObjectProtocol?
    private let closeButton = UIButton(type: .system)
    private let themeIconView = UIImageView()
    private let backgroundIconView = UIImageView()
    private let opacityIconView = UIImageView()
    private let tintIconView = UIImageView()
    private let textSizeIconView = UIImageView()
    private let readabilityIconView = UIImageView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "設定"
        configureUI()
        configureCloseButtonIfNeeded()
        applyTheme()
        themeObserver = NotificationCenter.default.addObserver(
            forName: ThemeManager.didChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyTheme()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureCloseButtonIfNeeded()
        applyTheme()
    }

    private func configureCloseButtonIfNeeded() {
        closeButton.setTitle("閉じる", for: .normal)
        closeButton.accessibilityLabel = "閉じる"
        closeButton.titleLabel?.font = AppFont.jp(size: 13, weight: .bold)
        closeButton.removeTarget(self, action: #selector(closeSelf), for: .touchUpInside)
        closeButton.addTarget(self, action: #selector(closeSelf), for: .touchUpInside)
        ThemeManager.styleSecondaryButton(closeButton)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: closeButton)
    }
 
    private func configureUI() {
        titleLabel.text = "THEME"
        titleLabel.textAlignment = .center
        subtitleLabel.text = "Color, background, and comfort"
        subtitleLabel.textAlignment = .center
        themeTitleLabel.text = "テーマカラー"
        themeTitleLabel.textAlignment = .left
        backgroundTitleLabel.text = "背景"
        backgroundTitleLabel.textAlignment = .left
        opacityTitleLabel.text = "写真の濃さ"
        opacityTitleLabel.textAlignment = .left
        opacityValueLabel.textAlignment = .right
        tintTitleLabel.text = "テーマ色味"
        tintTitleLabel.textAlignment = .left
        tintValueLabel.textAlignment = .right
        textSizeTitleLabel.text = "文字サイズ"
        textSizeTitleLabel.textAlignment = .left
        textSizeValueLabel.textAlignment = .right
        readabilityTitleLabel.text = "見やすさ"
        readabilityTitleLabel.textAlignment = .left
        readabilityValueLabel.textAlignment = .right

        let icons = [
            (themeIconView, "paintpalette.fill"),
            (backgroundIconView, "photo.fill"),
            (opacityIconView, "sun.max.fill"),
            (tintIconView, "music.note"),
            (textSizeIconView, "textformat.size"),
            (readabilityIconView, "bell.fill")
        ]
        icons.forEach { imageView, symbol in
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.image = UIImage(systemName: symbol)
            imageView.contentMode = .scaleAspectFit
        }

        themeStack.axis = .horizontal
        themeStack.spacing = AppSpacing.s(12)
        themeStack.alignment = .center
        themeStack.distribution = .fillEqually
        themeStack.translatesAutoresizingMaskIntoConstraints = false

        backgroundButton.translatesAutoresizingMaskIntoConstraints = false
        backgroundButton.setTitle("背景を選ぶ", for: .normal)
        backgroundButton.addTarget(self, action: #selector(openBackgroundMenu), for: .touchUpInside)

        opacitySlider.translatesAutoresizingMaskIntoConstraints = false
        opacitySlider.minimumValue = 0.25
        opacitySlider.maximumValue = 1.0
        opacitySlider.addTarget(self, action: #selector(opacityChanged(_:)), for: .valueChanged)

        tintSlider.translatesAutoresizingMaskIntoConstraints = false
        tintSlider.minimumValue = 0.08
        tintSlider.maximumValue = 0.28
        tintSlider.addTarget(self, action: #selector(tintChanged(_:)), for: .valueChanged)

        textSizeSegmented.translatesAutoresizingMaskIntoConstraints = false
        textSizeSegmented.addTarget(self, action: #selector(textSizeChanged(_:)), for: .valueChanged)

        readabilitySlider.translatesAutoresizingMaskIntoConstraints = false
        readabilitySlider.minimumValue = 0.0
        readabilitySlider.maximumValue = 0.55
        readabilitySlider.addTarget(self, action: #selector(readabilityChanged(_:)), for: .valueChanged)

        themeButtons = AppTheme.allCases.enumerated().map { index, theme in
            let button = UIButton(type: .system)
            button.tag = index
            button.layer.cornerRadius = 18
            button.layer.borderWidth = 2
            button.addTarget(self, action: #selector(selectTheme(_:)), for: .touchUpInside)
            return button
        }
        themeButtons.forEach { themeStack.addArrangedSubview($0) }

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.layer.cornerRadius = 24
        cardView.layer.borderWidth = 1.5

        let stack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, cardView])
        stack.axis = .vertical
        stack.spacing = AppSpacing.s(12)
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        cardView.addSubview(themeIconView)
        cardView.addSubview(themeTitleLabel)
        cardView.addSubview(themeStack)
        cardView.addSubview(backgroundIconView)
        cardView.addSubview(backgroundTitleLabel)
        cardView.addSubview(backgroundButton)
        cardView.addSubview(opacityIconView)
        cardView.addSubview(opacityTitleLabel)
        cardView.addSubview(opacityValueLabel)
        cardView.addSubview(opacitySlider)
        cardView.addSubview(tintIconView)
        cardView.addSubview(tintTitleLabel)
        cardView.addSubview(tintValueLabel)
        cardView.addSubview(tintSlider)
        cardView.addSubview(textSizeIconView)
        cardView.addSubview(textSizeTitleLabel)
        cardView.addSubview(textSizeValueLabel)
        cardView.addSubview(textSizeSegmented)
        cardView.addSubview(readabilityIconView)
        cardView.addSubview(readabilityTitleLabel)
        cardView.addSubview(readabilityValueLabel)
        cardView.addSubview(readabilitySlider)
        themeTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        backgroundTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        opacityTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        opacityValueLabel.translatesAutoresizingMaskIntoConstraints = false
        tintTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        tintValueLabel.translatesAutoresizingMaskIntoConstraints = false
        tintSlider.translatesAutoresizingMaskIntoConstraints = false
        textSizeTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        textSizeValueLabel.translatesAutoresizingMaskIntoConstraints = false
        textSizeSegmented.translatesAutoresizingMaskIntoConstraints = false
        readabilityTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        readabilityValueLabel.translatesAutoresizingMaskIntoConstraints = false
        readabilitySlider.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: AppSpacing.s(16)),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AppSpacing.s(16)),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AppSpacing.s(16)),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -AppSpacing.s(16)),

            cardView.bottomAnchor.constraint(equalTo: readabilitySlider.bottomAnchor, constant: AppSpacing.s(18)),

            themeIconView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: AppSpacing.s(16)),
            themeIconView.centerYAnchor.constraint(equalTo: themeTitleLabel.centerYAnchor),
            themeIconView.widthAnchor.constraint(equalToConstant: 18),
            themeIconView.heightAnchor.constraint(equalToConstant: 18),

            themeTitleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: AppSpacing.s(12)),
            themeTitleLabel.leadingAnchor.constraint(equalTo: themeIconView.trailingAnchor, constant: AppSpacing.s(8)),
            themeTitleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -AppSpacing.s(16)),

            themeStack.topAnchor.constraint(equalTo: themeTitleLabel.bottomAnchor, constant: AppSpacing.s(12)),
            themeStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: AppSpacing.s(16)),
            themeStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -AppSpacing.s(16)),
            themeStack.heightAnchor.constraint(equalToConstant: 36),

            backgroundIconView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: AppSpacing.s(16)),
            backgroundIconView.centerYAnchor.constraint(equalTo: backgroundTitleLabel.centerYAnchor),
            backgroundIconView.widthAnchor.constraint(equalToConstant: 18),
            backgroundIconView.heightAnchor.constraint(equalToConstant: 18),

            backgroundTitleLabel.topAnchor.constraint(equalTo: themeStack.bottomAnchor, constant: AppSpacing.s(20)),
            backgroundTitleLabel.leadingAnchor.constraint(equalTo: backgroundIconView.trailingAnchor, constant: AppSpacing.s(8)),
            backgroundTitleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -AppSpacing.s(16)),

            backgroundButton.topAnchor.constraint(equalTo: backgroundTitleLabel.bottomAnchor, constant: AppSpacing.s(10)),
            backgroundButton.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: AppSpacing.s(16)),
            backgroundButton.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -AppSpacing.s(16)),
            backgroundButton.heightAnchor.constraint(equalToConstant: 40),

            opacityIconView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: AppSpacing.s(16)),
            opacityIconView.centerYAnchor.constraint(equalTo: opacityTitleLabel.centerYAnchor),
            opacityIconView.widthAnchor.constraint(equalToConstant: 18),
            opacityIconView.heightAnchor.constraint(equalToConstant: 18),

            opacityTitleLabel.topAnchor.constraint(equalTo: backgroundButton.bottomAnchor, constant: AppSpacing.s(16)),
            opacityTitleLabel.leadingAnchor.constraint(equalTo: opacityIconView.trailingAnchor, constant: AppSpacing.s(8)),
            opacityTitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: opacityValueLabel.leadingAnchor, constant: -AppSpacing.s(8)),

            opacityValueLabel.centerYAnchor.constraint(equalTo: opacityTitleLabel.centerYAnchor),
            opacityValueLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -AppSpacing.s(16)),
            opacityValueLabel.widthAnchor.constraint(equalToConstant: 56),

            opacitySlider.topAnchor.constraint(equalTo: opacityTitleLabel.bottomAnchor, constant: AppSpacing.s(8)),
            opacitySlider.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: AppSpacing.s(16)),
            opacitySlider.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -AppSpacing.s(16)),

            tintIconView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: AppSpacing.s(16)),
            tintIconView.centerYAnchor.constraint(equalTo: tintTitleLabel.centerYAnchor),
            tintIconView.widthAnchor.constraint(equalToConstant: 18),
            tintIconView.heightAnchor.constraint(equalToConstant: 18),

            tintTitleLabel.topAnchor.constraint(equalTo: opacitySlider.bottomAnchor, constant: AppSpacing.s(18)),
            tintTitleLabel.leadingAnchor.constraint(equalTo: tintIconView.trailingAnchor, constant: AppSpacing.s(8)),
            tintTitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: tintValueLabel.leadingAnchor, constant: -AppSpacing.s(8)),

            tintValueLabel.centerYAnchor.constraint(equalTo: tintTitleLabel.centerYAnchor),
            tintValueLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -AppSpacing.s(16)),
            tintValueLabel.widthAnchor.constraint(equalToConstant: 56),

            tintSlider.topAnchor.constraint(equalTo: tintTitleLabel.bottomAnchor, constant: AppSpacing.s(8)),
            tintSlider.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: AppSpacing.s(16)),
            tintSlider.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -AppSpacing.s(16)),

            textSizeIconView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: AppSpacing.s(16)),
            textSizeIconView.centerYAnchor.constraint(equalTo: textSizeTitleLabel.centerYAnchor),
            textSizeIconView.widthAnchor.constraint(equalToConstant: 18),
            textSizeIconView.heightAnchor.constraint(equalToConstant: 18),

            textSizeTitleLabel.topAnchor.constraint(equalTo: tintSlider.bottomAnchor, constant: AppSpacing.s(18)),
            textSizeTitleLabel.leadingAnchor.constraint(equalTo: textSizeIconView.trailingAnchor, constant: AppSpacing.s(8)),
            textSizeTitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: textSizeValueLabel.leadingAnchor, constant: -AppSpacing.s(8)),

            textSizeValueLabel.centerYAnchor.constraint(equalTo: textSizeTitleLabel.centerYAnchor),
            textSizeValueLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -AppSpacing.s(16)),
            textSizeValueLabel.widthAnchor.constraint(equalToConstant: 64),

            textSizeSegmented.topAnchor.constraint(equalTo: textSizeTitleLabel.bottomAnchor, constant: AppSpacing.s(8)),
            textSizeSegmented.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: AppSpacing.s(16)),
            textSizeSegmented.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -AppSpacing.s(16)),
            textSizeSegmented.heightAnchor.constraint(equalToConstant: 36),

            readabilityIconView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: AppSpacing.s(16)),
            readabilityIconView.centerYAnchor.constraint(equalTo: readabilityTitleLabel.centerYAnchor),
            readabilityIconView.widthAnchor.constraint(equalToConstant: 18),
            readabilityIconView.heightAnchor.constraint(equalToConstant: 18),

            readabilityTitleLabel.topAnchor.constraint(equalTo: textSizeSegmented.bottomAnchor, constant: AppSpacing.s(18)),
            readabilityTitleLabel.leadingAnchor.constraint(equalTo: readabilityIconView.trailingAnchor, constant: AppSpacing.s(8)),
            readabilityTitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: readabilityValueLabel.leadingAnchor, constant: -AppSpacing.s(8)),

            readabilityValueLabel.centerYAnchor.constraint(equalTo: readabilityTitleLabel.centerYAnchor),
            readabilityValueLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -AppSpacing.s(16)),
            readabilityValueLabel.widthAnchor.constraint(equalToConstant: 64),

            readabilitySlider.topAnchor.constraint(equalTo: readabilityTitleLabel.bottomAnchor, constant: AppSpacing.s(8)),
            readabilitySlider.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: AppSpacing.s(16)),
            readabilitySlider.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -AppSpacing.s(16)),
        ])
    }

    @objc private func openBackgroundMenu() {
        let alert = UIAlertController(title: "背景画像", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "写真を選ぶ", style: .default) { [weak self] _ in
            self?.presentPhotoPicker()
        })
        if ThemeManager.modeBackgroundImage() != nil {
            alert.addAction(UIAlertAction(title: "背景をリセット", style: .destructive) { [weak self] _ in
                ThemeManager.clearModeBackgroundImage()
                self?.updateBackgroundButtonTitle()
            })
        }
        alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = backgroundButton
            popover.sourceRect = backgroundButton.bounds
        }
        present(alert, animated: true)
    }

    private func presentPhotoPicker() {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.selectionLimit = 1
        configuration.filter = .images
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider,
              provider.canLoadObject(ofClass: UIImage.self) else {
            return
        }
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let image = object as? UIImage else {
                return
            }
            ThemeManager.saveModeBackgroundImage(image)
            DispatchQueue.main.async {
                self?.updateBackgroundButtonTitle()
            }
        }
    }

    @objc private func opacityChanged(_ sender: UISlider) {
        ThemeManager.setModeBackgroundAlpha(CGFloat(sender.value))
        updateOpacityValueLabel()
    }

    @objc private func tintChanged(_ sender: UISlider) {
        ThemeManager.setThemeColorOverlayAlpha(CGFloat(sender.value))
        updateTintValueLabel()
    }

    @objc private func textSizeChanged(_ sender: UISegmentedControl) {
        let sizes = AppTextSize.allCases
        guard sender.selectedSegmentIndex >= 0, sender.selectedSegmentIndex < sizes.count else { return }
        ThemeManager.setTextSize(sizes[sender.selectedSegmentIndex])
        updateTextSizeValueLabel()
    }

    @objc private func readabilityChanged(_ sender: UISlider) {
        ThemeManager.setReadabilityOverlayAlpha(CGFloat(sender.value))
        updateReadabilityValueLabel()
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
        FontManager.applyPixelFont(to: view)
        if let navigationBar = navigationController?.navigationBar {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = palette.surface
            appearance.titleTextAttributes = [
                .foregroundColor: palette.text,
                .font: AppFont.jp(size: 18, weight: .bold)
            ]
            appearance.shadowColor = palette.border
            let barAttributes: [NSAttributedString.Key: Any] = [
                .font: AppFont.jp(size: 14, weight: .bold),
                .foregroundColor: palette.text
            ]
            appearance.buttonAppearance.normal.titleTextAttributes = barAttributes
            appearance.buttonAppearance.highlighted.titleTextAttributes = barAttributes
            appearance.doneButtonAppearance.normal.titleTextAttributes = barAttributes
            appearance.doneButtonAppearance.highlighted.titleTextAttributes = barAttributes
            navigationBar.standardAppearance = appearance
            navigationBar.scrollEdgeAppearance = appearance
            navigationBar.tintColor = palette.text
        }

        titleLabel.font = AppFont.title(size: 18)
        titleLabel.textColor = palette.text
        subtitleLabel.font = AppFont.en(size: 20)
        subtitleLabel.textColor = palette.mutedText
        themeTitleLabel.font = AppFont.jp(size: 15, weight: .bold)
        themeTitleLabel.textColor = palette.text
        backgroundTitleLabel.font = AppFont.jp(size: 15, weight: .bold)
        backgroundTitleLabel.textColor = palette.text
        opacityTitleLabel.font = AppFont.jp(size: 15, weight: .bold)
        opacityTitleLabel.textColor = palette.text
        opacityValueLabel.font = AppFont.en(size: 18)
        opacityValueLabel.textColor = palette.text
        tintTitleLabel.font = AppFont.jp(size: 15, weight: .bold)
        tintTitleLabel.textColor = palette.text
        tintValueLabel.font = AppFont.en(size: 18)
        tintValueLabel.textColor = palette.text
        textSizeTitleLabel.font = AppFont.jp(size: 15, weight: .bold)
        textSizeTitleLabel.textColor = palette.text
        textSizeValueLabel.font = AppFont.en(size: 18)
        textSizeValueLabel.textColor = palette.text
        readabilityTitleLabel.font = AppFont.jp(size: 15, weight: .bold)
        readabilityTitleLabel.textColor = palette.text
        readabilityValueLabel.font = AppFont.en(size: 18)
        readabilityValueLabel.textColor = palette.text
        [themeIconView, backgroundIconView, opacityIconView, tintIconView, textSizeIconView, readabilityIconView].forEach {
            $0.tintColor = palette.accentStrong
        }

        cardView.backgroundColor = palette.surface.withAlphaComponent(0.95)
        cardView.layer.borderColor = palette.border.cgColor
        cardView.layer.shadowColor = palette.border.cgColor
        cardView.layer.shadowOpacity = 0.12
        cardView.layer.shadowOffset = CGSize(width: 0, height: 8)
        cardView.layer.shadowRadius = 12
        backgroundButton.titleLabel?.font = AppFont.jp(size: 14, weight: .bold)
        ThemeManager.styleSecondaryButton(backgroundButton)
        ThemeManager.styleSecondaryButton(closeButton)
        opacitySlider.minimumTrackTintColor = palette.accentStrong
        opacitySlider.maximumTrackTintColor = palette.surfaceAlt
        opacitySlider.tintColor = palette.accent
        opacitySlider.value = Float(ThemeManager.modeBackgroundAlpha)
        tintSlider.minimumTrackTintColor = palette.accentStrong
        tintSlider.maximumTrackTintColor = palette.surfaceAlt
        tintSlider.tintColor = palette.accent
        tintSlider.value = Float(ThemeManager.themeColorOverlayAlpha)
        textSizeSegmented.selectedSegmentTintColor = palette.accent
        textSizeSegmented.backgroundColor = palette.surfaceAlt
        textSizeSegmented.setTitleTextAttributes([
            .font: AppFont.jp(size: 13, weight: .bold),
            .foregroundColor: palette.text
        ], for: .normal)
        textSizeSegmented.setTitleTextAttributes([
            .font: AppFont.jp(size: 13, weight: .bold),
            .foregroundColor: palette.text
        ], for: .selected)
        textSizeSegmented.selectedSegmentIndex = AppTextSize.allCases.firstIndex(of: ThemeManager.textSize) ?? 1
        readabilitySlider.minimumTrackTintColor = palette.accentStrong
        readabilitySlider.maximumTrackTintColor = palette.surfaceAlt
        readabilitySlider.tintColor = palette.accent
        readabilitySlider.value = Float(ThemeManager.readabilityOverlayAlpha)
        updateOpacityValueLabel()
        updateTintValueLabel()
        updateTextSizeValueLabel()
        updateReadabilityValueLabel()
        updateBackgroundButtonTitle()

        for (index, button) in themeButtons.enumerated() {
            let theme = AppTheme.allCases[index]
            button.backgroundColor = ThemeManager.palette(for: theme).accent
        }
        updateThemeSelection()
    }

    private func updateBackgroundButtonTitle() {
        let hasCustomBackground = ThemeManager.modeBackgroundImage() != nil
        let title = hasCustomBackground ? "背景を変更する" : "背景を選ぶ"
        backgroundButton.setTitle(title, for: .normal)
    }

    private func updateOpacityValueLabel() {
        let percent = Int(round(ThemeManager.modeBackgroundAlpha * 100))
        opacityValueLabel.text = "\(percent)%"
    }

    private func updateTintValueLabel() {
        let percent = Int(round(ThemeManager.themeColorOverlayAlpha * 100))
        tintValueLabel.text = "\(percent)%"
    }

    private func updateTextSizeValueLabel() {
        textSizeValueLabel.text = ThemeManager.textSize.displayName
    }

    private func updateReadabilityValueLabel() {
        let percent = Int(round(ThemeManager.readabilityOverlayAlpha / 0.55 * 100))
        readabilityValueLabel.text = "\(percent)%"
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

    @objc private func closeSelf() {
        if let navigationController, navigationController.viewControllers.first != self {
            navigationController.popViewController(animated: true)
        } else {
            presentingViewController?.dismiss(animated: true)
        }
    }

    deinit {
        if let observer = themeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
