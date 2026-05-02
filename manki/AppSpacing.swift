//
//  AppSpacing.swift
//  manki
//
//  Created by Codex on 2026/02/09.
//

import UIKit

enum AppSpacing {
    private static let baseWidth: CGFloat = 390
    private static let minScale: CGFloat = 0.85
    private static let maxScale: CGFloat = 1.12

    static var scale: CGFloat {
        let width = min(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
        let raw = width / baseWidth
        return min(max(raw, minScale), maxScale)
    }

    static func s(_ value: CGFloat) -> CGFloat {
        let scaled = value * scale
        return (scaled * 2).rounded(.toNearestOrAwayFromZero) / 2
    }

    static func s(_ value: Double) -> CGFloat {
        s(CGFloat(value))
    }

    static func s(_ value: Int) -> CGFloat {
        s(CGFloat(value))
    }
}

enum AppLayout {
    static let maxContentWidth: CGFloat = 540
    static let cardCornerRadius = AppSpacing.s(24)
    static let sectionSpacing = AppSpacing.s(18)
    static let contentVerticalInset = AppSpacing.s(16)
    static let minButtonHeight = AppSpacing.s(56)
    static let minCardHeight = AppSpacing.s(160)

    static func horizontalInset(for width: CGFloat) -> CGFloat {
        switch width {
        case ..<350:
            return AppSpacing.s(14)
        case ..<390:
            return AppSpacing.s(18)
        case ..<430:
            return AppSpacing.s(22)
        default:
            return AppSpacing.s(28)
        }
    }

    static func cardInnerPadding(for width: CGFloat) -> CGFloat {
        switch width {
        case ..<350:
            return AppSpacing.s(14)
        case ..<390:
            return AppSpacing.s(16)
        default:
            return AppSpacing.s(20)
        }
    }
}

enum AppTextStyle {
    case screenTitle
    case sectionTitle
    case body
    case emphasis
    case statValue
    case caption
    case button

    private var textStyle: UIFont.TextStyle {
        switch self {
        case .screenTitle:
            return .title2
        case .sectionTitle:
            return .headline
        case .body:
            return .body
        case .emphasis:
            return .title3
        case .statValue:
            return .title1
        case .caption:
            return .footnote
        case .button:
            return .headline
        }
    }

    private var baseSize: CGFloat {
        switch self {
        case .screenTitle:
            return AppSpacing.s(24)
        case .sectionTitle:
            return AppSpacing.s(16)
        case .body:
            return AppSpacing.s(15)
        case .emphasis:
            return AppSpacing.s(20)
        case .statValue:
            return AppSpacing.s(28)
        case .caption:
            return AppSpacing.s(12)
        case .button:
            return AppSpacing.s(16)
        }
    }

    private var weight: UIFont.Weight {
        switch self {
        case .screenTitle, .sectionTitle, .emphasis, .statValue, .button:
            return .bold
        case .body, .caption:
            return .regular
        }
    }

    func font() -> UIFont {
        let baseFont: UIFont
        switch self {
        case .screenTitle, .sectionTitle, .body, .caption, .button:
            baseFont = AppFont.jp(size: baseSize, weight: weight)
        case .emphasis, .statValue:
            baseFont = AppFont.en(size: baseSize, weight: weight)
        }
        return UIFontMetrics(forTextStyle: textStyle).scaledFont(for: baseFont)
    }
}

extension UILabel {
    func applyMankiTextStyle(
        _ style: AppTextStyle,
        color: UIColor,
        alignment: NSTextAlignment = .natural,
        numberOfLines: Int = 0
    ) {
        font = style.font()
        textColor = color
        textAlignment = alignment
        self.numberOfLines = numberOfLines
        adjustsFontForContentSizeCategory = true
        lineBreakMode = .byWordWrapping
        setContentCompressionResistancePriority(.required, for: .vertical)
    }
}

extension UIButton {
    func applyMankiButtonMetrics() {
        titleLabel?.font = AppTextStyle.button.font()
        titleLabel?.adjustsFontForContentSizeCategory = true
        titleLabel?.numberOfLines = 2
        titleLabel?.textAlignment = .center
        let insets = NSDirectionalEdgeInsets(
            top: AppSpacing.s(14),
            leading: AppSpacing.s(16),
            bottom: AppSpacing.s(14),
            trailing: AppSpacing.s(16)
        )
        if #available(iOS 15.0, *), var configuration {
            configuration.contentInsets = insets
            self.configuration = configuration
        } else {
            contentEdgeInsets = UIEdgeInsets(
                top: insets.top,
                left: insets.leading,
                bottom: insets.bottom,
                right: insets.trailing
            )
        }
        let hasHeightConstraint = constraints.contains { constraint in
            constraint.firstAttribute == .height && constraint.relation == .greaterThanOrEqual
        }
        if !hasHeightConstraint {
            let minHeightConstraint = heightAnchor.constraint(greaterThanOrEqualToConstant: AppLayout.minButtonHeight)
            // Let explicit sizing, especially navigation-bar custom views, win without logging constraint conflicts.
            minHeightConstraint.priority = .defaultHigh
            minHeightConstraint.isActive = true
        }
    }
}
