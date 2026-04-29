import UIKit

enum FontManager {
    enum Role {
        case title
        case navigationTitle
        case button
        case body
        case small
        case display
    }

    private static func scaled(_ size: CGFloat) -> CGFloat {
        size * ThemeManager.textScale
    }

    static func font(_ role: Role, size: CGFloat? = nil, weight: UIFont.Weight = .regular) -> UIFont {
        let pointSize = scaled(size ?? defaultSize(for: role))
        let names = fontNames(for: role, weight: weight)
        for name in names {
            if let font = UIFont(name: name, size: pointSize) {
                return font
            }
        }
        return UIFont.monospacedSystemFont(ofSize: pointSize, weight: weight)
    }

    static func pixelFont(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        font(.body, size: size, weight: weight)
    }

    static func applyPixelFont(to view: UIView) {
        var queue: [UIView] = [view]
        while !queue.isEmpty {
            let current = queue.removeFirst()
            let className = NSStringFromClass(type(of: current))
            if className.contains("UI") || className.contains("UILabel") || className.contains("UIButton") || className.contains("UIText") {
                if let label = current as? UILabel {
                    label.font = pixelFont(size: label.font.pointSize, weight: inferredWeight(from: label.font))
                } else if let button = current as? UIButton {
                    let size = button.titleLabel?.font.pointSize ?? defaultSize(for: .button)
                    button.titleLabel?.font = pixelFont(size: size, weight: .bold)
                } else if let textField = current as? UITextField {
                    let size = textField.font?.pointSize ?? defaultSize(for: .body)
                    textField.font = pixelFont(size: size, weight: inferredWeight(from: textField.font))
                } else if let textView = current as? UITextView {
                    let size = textView.font?.pointSize ?? defaultSize(for: .body)
                    textView.font = pixelFont(size: size, weight: inferredWeight(from: textView.font))
                }
            }

            let childViews = current.subviews.filter { child in
                let childClass = NSStringFromClass(type(of: child))
                return !childClass.contains("LayoutCanvasView") && !childClass.hasPrefix("_")
            }
            queue.append(contentsOf: childViews)
        }
    }

    static func applyGlobalAppearance() {
        UILabel.appearance().font = font(.body)
        UITextField.appearance().font = font(.body)
        UITextView.appearance().font = font(.body)
        UIButton.appearance().titleLabel?.font = font(.button, weight: .bold)
        UISegmentedControl.appearance().setTitleTextAttributes([.font: font(.small, weight: .bold)], for: .normal)
        UISegmentedControl.appearance().setTitleTextAttributes([.font: font(.small, weight: .bold)], for: .selected)
    }

    private static func defaultSize(for role: Role) -> CGFloat {
        switch role {
        case .title: return 24
        case .navigationTitle: return 18
        case .button: return 16
        case .body: return 15
        case .small: return 12
        case .display: return 28
        }
    }

    private static func fontNames(for role: Role, weight: UIFont.Weight) -> [String] {
        let jpPreferredBold = ["DotGothic16-Regular", "PixelMplus12-Bold", "PixelMplus10-Bold", "PressStart2P-Regular"]
        let jpPreferredRegular = ["DotGothic16-Regular", "PixelMplus12-Regular", "PixelMplus10-Regular", "PressStart2P-Regular"]

        switch role {
        case .display:
            return ["DotGothic16-Regular", "PressStart2P-Regular", "PixelMplus12-Bold", "PixelMplus12-Regular"]
        case .title:
            return ["DotGothic16-Regular", "PixelMplus12-Bold", "PixelMplus12-Regular", "PressStart2P-Regular"]
        case .navigationTitle, .button:
            return weight >= .semibold ? jpPreferredBold : jpPreferredRegular
        case .body:
            return weight >= .semibold ? jpPreferredBold : jpPreferredRegular
        case .small:
            return weight >= .semibold
                ? ["DotGothic16-Regular", "PixelMplus10-Bold", "PixelMplus12-Bold", "PressStart2P-Regular"]
                : ["DotGothic16-Regular", "PixelMplus10-Regular", "PixelMplus12-Regular", "PressStart2P-Regular"]
        }
    }

    private static func inferredWeight(from font: UIFont?) -> UIFont.Weight {
        guard let font else { return .regular }
        let traits = font.fontDescriptor.object(forKey: .traits) as? [UIFontDescriptor.TraitKey: Any]
        let rawWeight = traits?[.weight] as? CGFloat ?? UIFont.Weight.regular.rawValue
        return UIFont.Weight(rawValue: rawWeight)
    }
}
