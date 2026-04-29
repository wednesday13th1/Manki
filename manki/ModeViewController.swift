//
//  ModeViewController.swift
//  manki
//
//  Created by 井上　希稟 on 2026/01/24.
//

import UIKit

final class ModeViewController: UIViewController {

    private let backgroundImageView = UIImageView()
    private let colorOverlayView = UIView()
    private let dimmingOverlayView = UIView()
    private let contentView = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let startButton = UIButton(type: .system)
    private let menuButton = UIButton(type: .system)
    private let settingsButton = UIButton(type: .system)
    private let helperLabel = UILabel()
    private var themeObserver: NSObjectProtocol?
    private var isTransitioning = false
    private var sideMenu: SideMenuViewController?

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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applyTheme()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        isTransitioning = false
    }

    private func setupUI() {
        backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.clipsToBounds = true

        colorOverlayView.translatesAutoresizingMaskIntoConstraints = false
        colorOverlayView.isUserInteractionEnabled = false

        dimmingOverlayView.translatesAutoresizingMaskIntoConstraints = false
        dimmingOverlayView.isUserInteractionEnabled = false

        contentView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "MANKI"
        titleLabel.textAlignment = .center

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text = "開いたらすぐ1問。迷う前に学習開始。"
        subtitleLabel.numberOfLines = 0
        subtitleLabel.textAlignment = .center

        startButton.translatesAutoresizingMaskIntoConstraints = false
        startButton.setTitle("学習セットを開く", for: .normal)
        startButton.addTarget(self, action: #selector(openStudy), for: .touchUpInside)

        menuButton.translatesAutoresizingMaskIntoConstraints = false
        menuButton.setImage(UIImage(systemName: "line.3.horizontal"), for: .normal)
        menuButton.accessibilityLabel = "メニュー"
        menuButton.addTarget(self, action: #selector(openSideMenu), for: .touchUpInside)

        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.setImage(UIImage(systemName: "gearshape.fill"), for: .normal)
        settingsButton.accessibilityLabel = "設定"
        settingsButton.addTarget(self, action: #selector(openSettings), for: .touchUpInside)

        helperLabel.translatesAutoresizingMaskIntoConstraints = false
        helperLabel.text = "色や背景は右上の設定から変更できます"
        helperLabel.numberOfLines = 0
        helperLabel.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, startButton, helperLabel])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = AppSpacing.s(12)
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(backgroundImageView)
        view.addSubview(colorOverlayView)
        view.addSubview(dimmingOverlayView)
        view.addSubview(contentView)
        contentView.addSubview(menuButton)
        contentView.addSubview(settingsButton)
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            colorOverlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            colorOverlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            colorOverlayView.topAnchor.constraint(equalTo: view.topAnchor),
            colorOverlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            dimmingOverlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimmingOverlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dimmingOverlayView.topAnchor.constraint(equalTo: view.topAnchor),
            dimmingOverlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: view.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            menuButton.topAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.topAnchor, constant: AppSpacing.s(14)),
            menuButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AppSpacing.s(18)),
            menuButton.widthAnchor.constraint(equalToConstant: AppSpacing.s(46)),
            menuButton.heightAnchor.constraint(equalTo: menuButton.widthAnchor),

            settingsButton.topAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.topAnchor, constant: AppSpacing.s(14)),
            settingsButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -AppSpacing.s(18)),
            settingsButton.widthAnchor.constraint(equalToConstant: AppSpacing.s(46)),
            settingsButton.heightAnchor.constraint(equalTo: settingsButton.widthAnchor),

            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AppSpacing.s(24)),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -AppSpacing.s(24)),
            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            startButton.heightAnchor.constraint(equalToConstant: 64)
        ])
    }

    @objc private func openStudy() {
        guard !isTransitioning, presentedViewController == nil else { return }
        guard let controller = storyboard?.instantiateViewController(withIdentifier: "FolderNavigationController") else {
            return
        }
        isTransitioning = true
        controller.modalPresentationStyle = .fullScreen
        present(controller, animated: true) { [weak self] in
            self?.isTransitioning = false
        }
    }

    @objc private func openSideMenu() {
        guard sideMenu == nil else { return }
        let items = AppRoute.menuRoutes.map { route in
            return SideMenuItem(
                route: route,
                title: route.title,
                icon: route.menuIcon(tintColor: ThemeManager.palette().text),
                isSelected: route == .home
            ) { [weak self] in
                self?.open(routeFromHome: route)
            }
        }
        let menu = SideMenuViewController(items: items)
        menu.onDismiss = { [weak self] in
            self?.sideMenu = nil
        }
        sideMenu = menu
        menu.present(in: self)
    }

    private func open(routeFromHome route: AppRoute) {
        guard route != .home, !isTransitioning, presentedViewController == nil else { return }
        guard let controller = storyboard?.instantiateViewController(withIdentifier: "FolderNavigationController") else {
            return
        }
        if let navigationController = controller as? UINavigationController,
           route != .folder {
            AppRouter.navigate(to: route, from: navigationController)
        }
        isTransitioning = true
        controller.modalPresentationStyle = .fullScreen
        present(controller, animated: true) { [weak self] in
            self?.isTransitioning = false
        }
    }

    @objc private func openSettings() {
        guard presentedViewController == nil else { return }
        let controller = SettingViewController()
        let navigationController = MenuNavigationController(rootViewController: controller)
        navigationController.modalPresentationStyle = .formSheet
        present(navigationController, animated: true)
    }

    private func applyTheme() {
        let palette = ThemeManager.palette()
        view.backgroundColor = palette.background
        if let customBackground = ThemeManager.modeBackgroundImage() {
            backgroundImageView.image = customBackground
            backgroundImageView.alpha = ThemeManager.modeBackgroundAlpha
            ThemeManager.applyBackgroundOverlays(
                colorOverlayView: colorOverlayView,
                dimmingOverlayView: dimmingOverlayView,
                hasBackgroundImage: true
            )
        } else {
            backgroundImageView.image = backgroundImage(for: ThemeManager.current)
            backgroundImageView.alpha = 0.45
            colorOverlayView.backgroundColor = palette.background.withAlphaComponent(0.28)
            dimmingOverlayView.backgroundColor = .clear
        }

        titleLabel.font = AppFont.title(size: 24)
        titleLabel.textColor = palette.text

        subtitleLabel.font = AppFont.jp(size: 18, weight: .bold)
        subtitleLabel.textColor = palette.text

        helperLabel.font = AppFont.jp(size: 12, weight: .bold)
        helperLabel.textColor = palette.mutedText

        ThemeManager.stylePrimaryButton(startButton)
        startButton.titleLabel?.font = AppFont.jp(size: 18, weight: .bold)
        startButton.layer.borderWidth = 2

        [menuButton, settingsButton].forEach { button in
            ThemeManager.stylePixelIconButton(button)
        }

    }

    private func backgroundImage(for theme: AppTheme) -> UIImage? {
        let baseName: String
        switch theme {
        case .pink:
            baseName = "pnk"
        case .purple:
            baseName = "prpl"
        case .green:
            baseName = "grrn"
        case .yellow:
            baseName = "yllw"
        case .blue:
            baseName = "bleu"
        }
        return UIImage(named: baseName)
    }

    deinit {
        if let observer = themeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
