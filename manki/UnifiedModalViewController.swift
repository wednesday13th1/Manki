//
//  UnifiedModalViewController.swift
//  manki
//
//  Created by Codex on 2026/02/08.
//

import UIKit

struct UnifiedModalAction {
    enum Style {
        case normal
        case cancel
        case destructive
    }

    let title: String
    let style: Style
    let dismissOnTap: Bool
    let handler: (() -> Void)?

    init(title: String,
         style: Style = .normal,
         dismissOnTap: Bool = true,
         handler: (() -> Void)? = nil) {
        self.title = title
        self.style = style
        self.dismissOnTap = dismissOnTap
        self.handler = handler
    }
}

final class UnifiedModalViewController: UIViewController {

    private let modalTitle: String?
    private let modalMessage: String?
    private let contentView: UIView?
    private let actions: [UnifiedModalAction]
    private let allowOverlayDismiss: Bool

    private let overlay = UIControl()
    private let container = UIView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let buttonStack = UIStackView()
    private var actionButtons: [UIButton] = []
    private var themeObserver: NSObjectProtocol?

    init(title: String?,
         message: String?,
         contentView: UIView? = nil,
         actions: [UnifiedModalAction],
         allowOverlayDismiss: Bool = true) {
        self.modalTitle = title
        self.modalMessage = message
        self.contentView = contentView
        self.actions = actions
        self.allowOverlayDismiss = allowOverlayDismiss
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
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

        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.accessibilityViewIsModal = true
        if allowOverlayDismiss {
            overlay.addTarget(self, action: #selector(dismissModal), for: .touchUpInside)
        }

        container.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.text = modalTitle

        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.text = modalMessage

        let contentStack = UIStackView()
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = AppSpacing.s(10)

        if let title = modalTitle, !title.isEmpty {
            contentStack.addArrangedSubview(titleLabel)
        }
        if let message = modalMessage, !message.isEmpty {
            contentStack.addArrangedSubview(messageLabel)
        }
        if let custom = contentView {
            custom.translatesAutoresizingMaskIntoConstraints = false
            contentStack.addArrangedSubview(custom)
        }

        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.axis = .vertical
        buttonStack.spacing = AppSpacing.s(8)

        for (index, action) in actions.enumerated() {
            let button = makeButton(for: action, index: index)
            actionButtons.append(button)
            buttonStack.addArrangedSubview(button)
            let preferredHeight = button.heightAnchor.constraint(equalToConstant: 40)
            preferredHeight.priority = .defaultHigh
            preferredHeight.isActive = true
            let minHeight = button.heightAnchor.constraint(greaterThanOrEqualToConstant: 34)
            minHeight.priority = .defaultLow
            minHeight.isActive = true
        }

        container.addSubview(contentStack)
        container.addSubview(buttonStack)
        overlay.addSubview(container)
        view.addSubview(overlay)

        let maxWidth: CGFloat = 300
        NSLayoutConstraint.activate([
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            container.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            container.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            container.widthAnchor.constraint(lessThanOrEqualToConstant: maxWidth),
            container.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: AppSpacing.s(24)),
            container.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -AppSpacing.s(24)),

            contentStack.topAnchor.constraint(equalTo: container.topAnchor, constant: AppSpacing.s(16)),
            contentStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: AppSpacing.s(16)),
            contentStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -AppSpacing.s(16)),

            buttonStack.topAnchor.constraint(equalTo: contentStack.bottomAnchor, constant: AppSpacing.s(12)),
            buttonStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: AppSpacing.s(16)),
            buttonStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -AppSpacing.s(16)),
            buttonStack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -AppSpacing.s(16)),
        ])

        overlay.alpha = 0
        container.alpha = 0
        container.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseOut]) {
            self.overlay.alpha = 1
            self.container.alpha = 1
            self.container.transform = .identity
        }
    }

    private func makeButton(for action: UnifiedModalAction, index: Int) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.tag = index
        button.setTitle(action.title, for: .normal)
        button.titleLabel?.font = AppFont.jp(size: 16, weight: .bold)
        if var configuration = button.configuration {
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
            button.configuration = configuration
        } else {
            button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        }
        button.layer.borderWidth = 2
        button.layer.cornerRadius = 0
        button.layer.masksToBounds = true
        button.addTarget(self, action: #selector(handleAction(_:)), for: .touchUpInside)
        return button
    }

    private func applyTheme() {
        let palette = ThemeManager.palette()
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        container.backgroundColor = palette.surface
        container.layer.borderWidth = 2
        container.layer.borderColor = palette.border.cgColor

        titleLabel.font = AppFont.jp(size: 18, weight: .bold)
        titleLabel.textColor = palette.text
        messageLabel.font = AppFont.jp(size: 14, weight: .regular)
        messageLabel.textColor = palette.mutedText

        for (index, button) in actionButtons.enumerated() {
            let style = actions[index].style
            switch style {
            case .destructive:
                button.backgroundColor = palette.surfaceAlt
                button.layer.borderColor = UIColor.systemRed.cgColor
                button.setTitleColor(.systemRed, for: .normal)
            case .cancel:
                button.backgroundColor = palette.surfaceAlt
                button.layer.borderColor = palette.border.cgColor
                button.setTitleColor(palette.text, for: .normal)
            case .normal:
                button.backgroundColor = palette.surfaceAlt
                button.layer.borderColor = palette.border.cgColor
                button.setTitleColor(palette.text, for: .normal)
            }
        }
    }

    @objc private func handleAction(_ sender: UIButton) {
        let action = actions[sender.tag]
        if action.dismissOnTap {
            dismissAnimated { action.handler?() }
        } else {
            action.handler?()
        }
    }

    @objc private func dismissModal() {
        dismissAnimated(completion: nil)
    }

    private func dismissAnimated(completion: (() -> Void)?) {
        UIView.animate(withDuration: 0.15, delay: 0, options: [.curveEaseIn]) {
            self.overlay.alpha = 0
            self.container.alpha = 0
            self.container.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        } completion: { _ in
            self.dismiss(animated: false, completion: completion)
        }
    }
}

extension UIViewController {
    func presentUnifiedModal(title: String?,
                             message: String?,
                             contentView: UIView? = nil,
                             actions: [UnifiedModalAction],
                             allowOverlayDismiss: Bool = true) {
        let modal = UnifiedModalViewController(title: title,
                                               message: message,
                                               contentView: contentView,
                                               actions: actions,
                                               allowOverlayDismiss: allowOverlayDismiss)
        present(modal, animated: false)
    }
}
