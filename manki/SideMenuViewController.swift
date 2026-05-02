import UIKit

final class SideMenuViewController: UIViewController {
    private let menuWidth: CGFloat = 304
    private let horizontalMargin = AppSpacing.s(16)
    private let dimmingView = UIControl()
    private let menuContainer = UIView()
    private let menuStack = UIStackView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private var items: [SideMenuItem]
    private var themeObserver: NSObjectProtocol?
    private let menuHeaderBadge = UIView()
    private var menuWidthConstraint: NSLayoutConstraint?

    var onDismiss: (() -> Void)?

    init(items: [SideMenuItem]) {
        self.items = items
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .coverVertical
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        applyTheme()
        themeObserver = NotificationCenter.default.addObserver(
            forName: ThemeManager.didChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyTheme()
        }
    }

    deinit {
        if let observer = themeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func configureUI() {
        view.backgroundColor = .clear

        dimmingView.translatesAutoresizingMaskIntoConstraints = false
        dimmingView.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        dimmingView.alpha = 0
        dimmingView.addTarget(self, action: #selector(handleClose), for: .touchUpInside)

        menuContainer.translatesAutoresizingMaskIntoConstraints = false
        menuContainer.layer.cornerRadius = 30
        menuContainer.layer.borderWidth = 2
        menuContainer.layer.shadowColor = UIColor.black.cgColor
        menuContainer.layer.shadowOpacity = 0.16
        menuContainer.layer.shadowOffset = CGSize(width: 0, height: 10)
        menuContainer.layer.shadowRadius = 18

        menuHeaderBadge.translatesAutoresizingMaskIntoConstraints = false
        menuHeaderBadge.layer.cornerRadius = 16
        menuHeaderBadge.layer.borderWidth = 2

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "MANKI MENU"
        titleLabel.textAlignment = .left
        titleLabel.numberOfLines = 0

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text = "アプリの画面を切り替えます"
        subtitleLabel.textAlignment = .left
        subtitleLabel.numberOfLines = 0

        menuStack.translatesAutoresizingMaskIntoConstraints = false
        menuStack.axis = .vertical
        menuStack.spacing = AppSpacing.s(12)
        menuStack.alignment = .fill

        view.addSubview(dimmingView)
        view.addSubview(menuContainer)
        menuContainer.addSubview(menuHeaderBadge)
        menuContainer.addSubview(titleLabel)
        menuContainer.addSubview(subtitleLabel)
        menuContainer.addSubview(menuStack)

        menuWidthConstraint = menuContainer.widthAnchor.constraint(equalToConstant: menuWidth)

        NSLayoutConstraint.activate([
            dimmingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimmingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dimmingView.topAnchor.constraint(equalTo: view.topAnchor),
            dimmingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            menuContainer.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: horizontalMargin),
            menuContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: AppSpacing.s(10)),
            menuContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -AppSpacing.s(10)),
            menuContainer.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -horizontalMargin),

            menuHeaderBadge.topAnchor.constraint(equalTo: menuContainer.topAnchor, constant: AppSpacing.s(18)),
            menuHeaderBadge.leadingAnchor.constraint(equalTo: menuContainer.leadingAnchor, constant: AppSpacing.s(18)),
            menuHeaderBadge.trailingAnchor.constraint(equalTo: menuContainer.trailingAnchor, constant: -AppSpacing.s(18)),

            titleLabel.topAnchor.constraint(equalTo: menuHeaderBadge.topAnchor, constant: AppSpacing.s(12)),
            titleLabel.leadingAnchor.constraint(equalTo: menuContainer.leadingAnchor, constant: AppSpacing.s(22)),
            titleLabel.trailingAnchor.constraint(equalTo: menuContainer.trailingAnchor, constant: -AppSpacing.s(22)),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: AppSpacing.s(4)),
            subtitleLabel.leadingAnchor.constraint(equalTo: menuContainer.leadingAnchor, constant: AppSpacing.s(22)),
            subtitleLabel.trailingAnchor.constraint(equalTo: menuContainer.trailingAnchor, constant: -AppSpacing.s(22)),
            subtitleLabel.bottomAnchor.constraint(equalTo: menuHeaderBadge.bottomAnchor, constant: -AppSpacing.s(12)),

            menuStack.topAnchor.constraint(equalTo: menuHeaderBadge.bottomAnchor, constant: AppSpacing.s(20)),
            menuStack.leadingAnchor.constraint(equalTo: menuContainer.leadingAnchor, constant: AppSpacing.s(18)),
            menuStack.trailingAnchor.constraint(equalTo: menuContainer.trailingAnchor, constant: -AppSpacing.s(18)),
            menuStack.bottomAnchor.constraint(lessThanOrEqualTo: menuContainer.bottomAnchor, constant: -AppSpacing.s(22))
        ])
        menuWidthConstraint?.isActive = true

        updateMenuItems()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateMenuWidthIfNeeded()
    }

    private func updateMenuItems() {
        menuStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        items.enumerated().forEach { index, item in
            let button = UIButton(type: .system)
            button.tag = index
            var configuration = UIButton.Configuration.plain()
            configuration.contentInsets = NSDirectionalEdgeInsets(
                top: AppSpacing.s(14),
                leading: AppSpacing.s(18),
                bottom: AppSpacing.s(14),
                trailing: AppSpacing.s(18)
            )
            configuration.imagePlacement = .leading
            configuration.imagePadding = AppSpacing.s(12)
            configuration.titleAlignment = .leading
            button.configuration = configuration
            button.contentHorizontalAlignment = .leading
            button.titleLabel?.font = FontManager.font(.button, size: 16, weight: .bold)
            button.titleLabel?.numberOfLines = 2
            button.titleLabel?.adjustsFontSizeToFitWidth = true
            button.titleLabel?.minimumScaleFactor = 0.82
            button.setTitle(item.title, for: .normal)
            button.tintColor = ThemeManager.palette().text
            if let icon = item.icon {
                UIView.performWithoutAnimation {
                    button.setImage(icon, for: .normal)
                    button.layoutIfNeeded()
                }
            }
            button.imageView?.contentMode = .scaleAspectFit
            button.layer.cornerRadius = 18
            button.layer.borderWidth = item.isSelected ? 2 : 1.5
            button.addTarget(self, action: #selector(handleItemTap(_:)), for: .touchUpInside)
            menuStack.addArrangedSubview(button)

            let height = button.heightAnchor.constraint(equalToConstant: AppSpacing.s(56))
            height.priority = .required
            height.isActive = true
        }
    }

    private func applyTheme() {
        let palette = ThemeManager.palette()
        menuContainer.backgroundColor = palette.surface.withAlphaComponent(0.96)
        menuContainer.layer.borderColor = palette.border.cgColor
        menuHeaderBadge.backgroundColor = palette.background.withAlphaComponent(0.72)
        menuHeaderBadge.layer.borderColor = palette.border.cgColor
        titleLabel.textColor = palette.text
        titleLabel.font = FontManager.font(.display, size: 20, weight: .regular)
        subtitleLabel.textColor = palette.mutedText
        subtitleLabel.font = AppFont.en(size: 18)

        menuStack.arrangedSubviews.forEach { view in
            guard let button = view as? UIButton else { return }
            let item = items[button.tag]
            button.setTitleColor(palette.text, for: .normal)
            button.configurationUpdateHandler = { [weak self] button in
                guard let self else { return }
                let currentPalette = ThemeManager.palette()
                let currentItem = self.items[button.tag]
                let isPressed = button.isHighlighted
                let normalColor = currentItem.isSelected ? currentPalette.accent : currentPalette.surfaceAlt.withAlphaComponent(0.92)
                let pressedColor = currentItem.isSelected ? currentPalette.accentStrong : currentPalette.surface
                button.backgroundColor = isPressed ? pressedColor : normalColor
                button.layer.shadowColor = currentPalette.border.cgColor
                button.layer.shadowRadius = 0
                button.layer.shadowOpacity = currentItem.isSelected ? 0.16 : 0.1
                button.layer.shadowOffset = isPressed ? CGSize(width: 0, height: 1) : CGSize(width: 0, height: 4)
                button.transform = isPressed ? CGAffineTransform(translationX: 0, y: 3) : .identity
            }
            let icon = item.route.menuIcon(tintColor: palette.text)
            UIView.performWithoutAnimation {
                button.setImage(icon, for: .normal)
                button.layoutIfNeeded()
            }
            button.backgroundColor = item.isSelected ? palette.accent : palette.surfaceAlt.withAlphaComponent(0.92)
            button.layer.borderColor = palette.border.cgColor
            button.layer.borderWidth = item.isSelected ? 2 : 1.5
            button.layer.shadowColor = palette.border.cgColor
            button.layer.shadowOpacity = item.isSelected ? 0.16 : 0.1
            button.layer.shadowOffset = CGSize(width: 0, height: 4)
            button.layer.shadowRadius = 0
            button.accessibilityTraits = item.isSelected ? [.button, .selected] : [.button]
            UIView.performWithoutAnimation {
                button.setNeedsUpdateConfiguration()
                button.layoutIfNeeded()
            }
        }
    }

    private func updateMenuWidthIfNeeded() {
        let availableWidth = max(220, view.safeAreaLayoutGuide.layoutFrame.width - (horizontalMargin * 2))
        let targetWidth = min(menuWidth, availableWidth)
        guard menuWidthConstraint?.constant != targetWidth else { return }
        menuWidthConstraint?.constant = targetWidth
    }

    func present(in parent: UIViewController) {
        parent.present(self, animated: false) { [weak self] in
            self?.animateIn()
        }
    }

    private func animateIn() {
        updateMenuWidthIfNeeded()
        let translation = menuWidthConstraint?.constant ?? menuWidth
        menuContainer.transform = CGAffineTransform(translationX: -translation, y: 0)
        dimmingView.alpha = 0
        UIView.animate(withDuration: 0.26, delay: 0, options: [.curveEaseOut, .allowUserInteraction]) {
            self.dimmingView.alpha = 1
            self.menuContainer.transform = .identity
        }
    }

    private func animateOut(completion: (() -> Void)? = nil) {
        let translation = menuWidthConstraint?.constant ?? menuWidth
        UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseInOut, .allowUserInteraction]) {
            self.dimmingView.alpha = 0
            self.menuContainer.transform = CGAffineTransform(translationX: -translation, y: 0)
        } completion: { _ in
            completion?()
        }
    }

    @objc private func handleClose() {
        animateOut { [weak self] in
            self?.dismiss(animated: false) {
                self?.onDismiss?()
            }
        }
    }

    @objc private func handleItemTap(_ sender: UIButton) {
        guard sender.tag >= 0, sender.tag < items.count else { return }
        let action = items[sender.tag].action
        animateOut { [weak self] in
            self?.dismiss(animated: false) {
                self?.onDismiss?()
                action()
            }
        }
    }
}
