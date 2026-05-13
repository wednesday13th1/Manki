import UIKit

final class SideMenuViewController: UIViewController {
    private let menuWidth: CGFloat = 304
    private let minMenuWidth: CGFloat = 260
    private let horizontalMargin = AppSpacing.s(10)
    private let dimmingView = UIControl()
    private let menuContainer = UIView()
    private let scrollView = UIScrollView()
    private let contentView = UIView()
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

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.clipsToBounds = true

        contentView.translatesAutoresizingMaskIntoConstraints = false

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
        menuContainer.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(menuHeaderBadge)
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(menuStack)

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

            scrollView.topAnchor.constraint(equalTo: menuContainer.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: menuContainer.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: menuContainer.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: menuContainer.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            menuHeaderBadge.topAnchor.constraint(equalTo: contentView.topAnchor, constant: AppSpacing.s(18)),
            menuHeaderBadge.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AppSpacing.s(14)),
            menuHeaderBadge.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -AppSpacing.s(14)),

            titleLabel.topAnchor.constraint(equalTo: menuHeaderBadge.topAnchor, constant: AppSpacing.s(12)),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AppSpacing.s(18)),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -AppSpacing.s(18)),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: AppSpacing.s(4)),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AppSpacing.s(18)),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -AppSpacing.s(18)),
            subtitleLabel.bottomAnchor.constraint(equalTo: menuHeaderBadge.bottomAnchor, constant: -AppSpacing.s(12)),

            menuStack.topAnchor.constraint(equalTo: menuHeaderBadge.bottomAnchor, constant: AppSpacing.s(20)),
            menuStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AppSpacing.s(12)),
            menuStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -AppSpacing.s(12)),
            menuStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -AppSpacing.s(22))
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
            let button = SideMenuRowButton()
            button.tag = index
            button.itemIndex = index
            button.configure(
                title: item.title,
                icon: item.icon,
                route: item.route
            )
            button.tintColor = ThemeManager.palette().text
            button.layer.cornerRadius = 18
            button.layer.borderWidth = item.isSelected ? 2 : 1.5
            button.addTarget(self, action: #selector(handleItemTap(_:)), for: .touchUpInside)
            button.onHighlightChanged = { [weak self, weak button] in
                guard let self, let button else { return }
                self.updateRowAppearance(button)
            }
            menuStack.addArrangedSubview(button)

            let height = button.heightAnchor.constraint(greaterThanOrEqualToConstant: AppSpacing.s(56))
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
            guard let button = view as? SideMenuRowButton else { return }
            let item = items[button.tag]
            button.menuTitleLabel.font = UIFontMetrics(forTextStyle: .body).scaledFont(
                for: FontManager.font(.button, size: 16, weight: .bold)
            )
            button.menuTitleLabel.textColor = palette.text
            button.iconView.isHidden = false
            button.iconView.alpha = 1
            button.applyIconColor(button.iconColor)
            button.layer.borderColor = palette.border.cgColor
            button.layer.borderWidth = item.isSelected ? 2 : 1.5
            button.accessibilityTraits = item.isSelected ? [.button, .selected] : [.button]
            updateRowAppearance(button, animated: false)
        }
    }

    private func updateRowAppearance(_ button: SideMenuRowButton, animated: Bool = true) {
        guard button.tag >= 0, button.tag < items.count else { return }
        let palette = ThemeManager.palette()
        let item = items[button.tag]
        let normalColor = item.isSelected ? palette.accent.withAlphaComponent(0.45) : palette.surfaceAlt.withAlphaComponent(0.92)
        let pressedColor = item.isSelected ? palette.accent.withAlphaComponent(0.65) : palette.surface
        let updates = {
            button.backgroundColor = button.isHighlighted ? pressedColor : normalColor
            button.layer.shadowColor = palette.border.cgColor
            button.layer.shadowOpacity = item.isSelected ? 0.16 : 0.1
            button.layer.shadowOffset = button.isHighlighted ? CGSize(width: 0, height: 1) : CGSize(width: 0, height: 4)
            button.layer.shadowRadius = 0
            button.transform = button.isHighlighted ? CGAffineTransform(translationX: 0, y: 3) : .identity
        }

        if animated {
            UIView.animate(withDuration: 0.08, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction], animations: updates)
        } else {
            updates()
        }
    }

    private func updateMenuWidthIfNeeded() {
        let availableWidth = max(minMenuWidth, view.safeAreaLayoutGuide.layoutFrame.width - (horizontalMargin * 2))
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

    @objc private func handleItemTap(_ sender: UIControl) {
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

private final class SideMenuRowButton: UIControl {
    let iconView = UIImageView(image: UIImage(systemName: "circle.fill"))
    let menuTitleLabel = UILabel()
    private let iconContainer = UIView()
    private let rowStack = UIStackView()
    private var currentSymbolName = "circle.fill"
    let iconColor = UIColor(red: 0.16, green: 0.10, blue: 0.09, alpha: 1)
    var itemIndex = 0
    var onHighlightChanged: (() -> Void)?

    override var isHighlighted: Bool {
        didSet {
            onHighlightChanged?()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        bringSubviewToFront(rowStack)
        iconContainer.bringSubviewToFront(iconView)
    }

    func configure(title: String, icon: UIImage?, route: AppRoute) {
        menuTitleLabel.text = title
        currentSymbolName = route.systemImageName.isEmpty ? "circle.fill" : route.systemImageName
        iconView.image = makeIconImage(symbolName: currentSymbolName, color: iconColor)
            ?? icon?.withTintColor(iconColor, renderingMode: .alwaysOriginal)
            ?? UIImage(systemName: "circle.fill")?.withTintColor(iconColor, renderingMode: .alwaysOriginal)
        iconView.isHidden = false
        iconView.alpha = 1
        iconView.tintColor = iconColor
        accessibilityLabel = title
    }

    func applyIconColor(_ color: UIColor) {
        iconView.image = makeIconImage(symbolName: currentSymbolName, color: color)
        iconView.tintColor = color
        iconView.isHidden = false
        iconView.alpha = 1
    }

    private func makeIconImage(symbolName: String, color: UIColor) -> UIImage? {
        let configuration = UIImage.SymbolConfiguration(pointSize: 24, weight: .semibold, scale: .medium)
        let symbol = UIImage(systemName: symbolName, withConfiguration: configuration)
            ?? UIImage(systemName: "circle.fill", withConfiguration: configuration)
        return symbol?.withTintColor(color, renderingMode: .alwaysOriginal)
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        isAccessibilityElement = true
        accessibilityTraits = .button

        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.isUserInteractionEnabled = false
        iconContainer.backgroundColor = .clear
        iconContainer.setContentHuggingPriority(.required, for: .horizontal)
        iconContainer.setContentCompressionResistancePriority(.required, for: .horizontal)

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFit
        iconView.isHidden = false
        iconView.tintColor = iconColor
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 24, weight: .semibold)
        iconView.layer.zPosition = 2
        iconView.setContentHuggingPriority(.required, for: .horizontal)
        iconView.setContentCompressionResistancePriority(.required, for: .horizontal)

        menuTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        menuTitleLabel.numberOfLines = 2
        menuTitleLabel.adjustsFontForContentSizeCategory = true
        menuTitleLabel.adjustsFontSizeToFitWidth = true
        menuTitleLabel.minimumScaleFactor = 0.7
        menuTitleLabel.lineBreakMode = .byTruncatingTail
        menuTitleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        rowStack.translatesAutoresizingMaskIntoConstraints = false
        rowStack.axis = .horizontal
        rowStack.alignment = .center
        rowStack.spacing = AppSpacing.s(12)
        rowStack.distribution = .fill
        rowStack.isUserInteractionEnabled = false
        rowStack.layer.zPosition = 1
        iconContainer.addSubview(iconView)
        rowStack.addArrangedSubview(iconContainer)
        rowStack.addArrangedSubview(menuTitleLabel)

        addSubview(rowStack)

        NSLayoutConstraint.activate([
            rowStack.topAnchor.constraint(equalTo: topAnchor, constant: AppSpacing.s(10)),
            rowStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: AppSpacing.s(14)),
            rowStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -AppSpacing.s(14)),
            rowStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -AppSpacing.s(10)),
            iconContainer.widthAnchor.constraint(equalToConstant: 28),
            iconContainer.heightAnchor.constraint(equalToConstant: 28),
            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 22),
            iconView.heightAnchor.constraint(equalToConstant: 22)
        ])
    }
}
