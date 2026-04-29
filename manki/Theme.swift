//
//  Theme.swift
//  manki
//
//  Created by Codex on 2026/01/25.
//

import UIKit

enum AppTheme: String, CaseIterable {
    case yellow
    case green
    case pink
    case blue
    case purple

    var displayName: String {
        switch self {
        case .yellow: return "Yellow"
        case .green: return "Green"
        case .pink: return "Pink"
        case .blue: return "Blue"
        case .purple: return "Purple"
        }
    }
}

enum AppTextSize: String, CaseIterable {
    case small
    case medium
    case large

    var displayName: String {
        switch self {
        case .small: return "小"
        case .medium: return "中"
        case .large: return "大"
        }
    }

    var scale: CGFloat {
        switch self {
        case .small: return 0.92
        case .medium: return 1.0
        case .large: return 1.14
        }
    }
}

struct ThemePalette {
    let background: UIColor
    let surface: UIColor
    let surfaceAlt: UIColor
    let accent: UIColor
    let accentStrong: UIColor
    let border: UIColor
    let text: UIColor
    let mutedText: UIColor
    let dot: UIColor
}

enum AppFont {
    static func jp(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        FontManager.font(.body, size: size, weight: weight)
    }

    static func en(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        FontManager.font(.body, size: size, weight: weight)
    }

    static func title(size: CGFloat) -> UIFont {
        FontManager.font(.title, size: size, weight: .bold)
    }
}

enum ThemeManager {
    static let didChange = Notification.Name("ThemeManagerDidChange")
    private static let storageKey = "manki.theme.current"
    private static let modeBackgroundAlphaKey = "manki.mode.background.alpha"
    private static let textScaleKey = "manki.display.text.scale"
    private static let textSizeKey = "manki.display.text.size"
    private static let readabilityOverlayKey = "manki.display.readability.overlay"
    private static let themeColorOverlayKey = "manki.display.theme.color.overlay"
    private static let backgroundImageTag = 9831
    private static let backgroundTag = 9832
    private static let readabilityOverlayTag = 9833
    private static let colorOverlayTag = 9834
    private static let modeBackgroundFileName = "mode_custom_background.jpg"
    private static var cachedPatterns: [AppTheme: UIImage] = [:]

    static var current: AppTheme {
        get {
            if let raw = UserDefaults.standard.string(forKey: storageKey),
               let theme = AppTheme(rawValue: raw) {
                return theme
            }
            return .yellow
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: storageKey)
        }
    }

    static func setTheme(_ theme: AppTheme) {
        current = theme
        NotificationCenter.default.post(name: didChange, object: nil)
    }

    static func modeBackgroundImage() -> UIImage? {
        guard let fileURL = modeBackgroundFileURL() else {
            return nil
        }
        return UIImage(contentsOfFile: fileURL.path)
    }

    static func saveModeBackgroundImage(_ image: UIImage) {
        guard let fileURL = modeBackgroundFileURL(),
              let data = image.jpegData(compressionQuality: 0.85) else {
            return
        }
        try? data.write(to: fileURL, options: .atomic)
        NotificationCenter.default.post(name: didChange, object: nil)
    }

    static func clearModeBackgroundImage() {
        guard let fileURL = modeBackgroundFileURL() else {
            return
        }
        try? FileManager.default.removeItem(at: fileURL)
        NotificationCenter.default.post(name: didChange, object: nil)
    }

    static var modeBackgroundAlpha: CGFloat {
        let stored = UserDefaults.standard.object(forKey: modeBackgroundAlphaKey) as? Double
        let defaultValue = 0.8
        let value = stored ?? defaultValue
        return CGFloat(min(max(value, 0.25), 1.0))
    }

    static func setModeBackgroundAlpha(_ alpha: CGFloat) {
        let clamped = min(max(alpha, 0.25), 1.0)
        UserDefaults.standard.set(Double(clamped), forKey: modeBackgroundAlphaKey)
        NotificationCenter.default.post(name: didChange, object: nil)
    }

    static var textScale: CGFloat {
        if UserDefaults.standard.object(forKey: textScaleKey) == nil {
            return textSize.scale
        }
        let stored = UserDefaults.standard.object(forKey: textScaleKey) as? Double
        let value = stored ?? 1.0
        return CGFloat(min(max(value, 0.85), 1.25))
    }

    static func setTextScale(_ scale: CGFloat) {
        let clamped = min(max(scale, 0.85), 1.25)
        UserDefaults.standard.set(Double(clamped), forKey: textScaleKey)
        NotificationCenter.default.post(name: didChange, object: nil)
    }

    static var textSize: AppTextSize {
        get {
            if let raw = UserDefaults.standard.string(forKey: textSizeKey),
               let size = AppTextSize(rawValue: raw) {
                return size
            }
            return .medium
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: textSizeKey)
            UserDefaults.standard.set(Double(newValue.scale), forKey: textScaleKey)
        }
    }

    static func setTextSize(_ size: AppTextSize) {
        textSize = size
        NotificationCenter.default.post(name: didChange, object: nil)
    }

    static var readabilityOverlayAlpha: CGFloat {
        let stored = UserDefaults.standard.object(forKey: readabilityOverlayKey) as? Double
        let value = stored ?? 0.18
        return CGFloat(min(max(value, 0.0), 0.55))
    }

    static func setReadabilityOverlayAlpha(_ alpha: CGFloat) {
        let clamped = min(max(alpha, 0.0), 0.55)
        UserDefaults.standard.set(Double(clamped), forKey: readabilityOverlayKey)
        NotificationCenter.default.post(name: didChange, object: nil)
    }

    static var themeColorOverlayAlpha: CGFloat {
        let stored = UserDefaults.standard.object(forKey: themeColorOverlayKey) as? Double
        let value = stored ?? 0.18
        return CGFloat(min(max(value, 0.08), 0.28))
    }

    static func setThemeColorOverlayAlpha(_ alpha: CGFloat) {
        let clamped = min(max(alpha, 0.08), 0.28)
        UserDefaults.standard.set(Double(clamped), forKey: themeColorOverlayKey)
        NotificationCenter.default.post(name: didChange, object: nil)
    }

    static func palette(for theme: AppTheme = current) -> ThemePalette {
        switch theme {
        case .yellow:
            return ThemePalette(
                background: UIColor(hex: 0xFFF6DE),
                surface: UIColor(hex: 0xFFF1C7),
                surfaceAlt: UIColor(hex: 0xFFE6A3),
                accent: UIColor(hex: 0xF2B705),
                accentStrong: UIColor(hex: 0xD59A00),
                border: UIColor(hex: 0x2A2A2A),
                text: UIColor(hex: 0x1F1F1F),
                mutedText: UIColor(hex: 0x5A5A5A),
                dot: UIColor(hex: 0xF2B705, alpha: 0.25)
            )
        case .green:
            return ThemePalette(
                background: UIColor(hex: 0xEAF9E6),
                surface: UIColor(hex: 0xDDF3D5),
                surfaceAlt: UIColor(hex: 0xBEE8B2),
                accent: UIColor(hex: 0x70C35B),
                accentStrong: UIColor(hex: 0x4DA645),
                border: UIColor(hex: 0x1E2A1E),
                text: UIColor(hex: 0x1E261E),
                mutedText: UIColor(hex: 0x4F5F4F),
                dot: UIColor(hex: 0x70C35B, alpha: 0.25)
            )
        case .pink:
            return ThemePalette(
                background: UIColor(hex: 0xFBE6F2),
                surface: UIColor(hex: 0xF6D1E7),
                surfaceAlt: UIColor(hex: 0xF1B6D8),
                accent: UIColor(hex: 0xE15BAA),
                accentStrong: UIColor(hex: 0xC83B8E),
                border: UIColor(hex: 0x2A1F2A),
                text: UIColor(hex: 0x281B25),
                mutedText: UIColor(hex: 0x5A4451),
                dot: UIColor(hex: 0xE15BAA, alpha: 0.25)
            )
        case .blue:
            return ThemePalette(
                background: UIColor(hex: 0xE6F2FF),
                surface: UIColor(hex: 0xD6E8FF),
                surfaceAlt: UIColor(hex: 0xB9D9FF),
                accent: UIColor(hex: 0x4DA3FF),
                accentStrong: UIColor(hex: 0x1C7BE6),
                border: UIColor(hex: 0x1C2530),
                text: UIColor(hex: 0x162233),
                mutedText: UIColor(hex: 0x445669),
                dot: UIColor(hex: 0x4DA3FF, alpha: 0.25)
            )
        case .purple:
            return ThemePalette(
                background: UIColor(hex: 0xEFE6FF),
                surface: UIColor(hex: 0xE2D6FF),
                surfaceAlt: UIColor(hex: 0xCDBBFF),
                accent: UIColor(hex: 0x8B6DFF),
                accentStrong: UIColor(hex: 0x6A4DDA),
                border: UIColor(hex: 0x211C2C),
                text: UIColor(hex: 0x1F1C2B),
                mutedText: UIColor(hex: 0x4C445C),
                dot: UIColor(hex: 0x8B6DFF, alpha: 0.25)
            )
        }
    }

    static func applyBackground(to view: UIView) {
        let palette = palette()
        view.backgroundColor = palette.background

        let imageView: UIImageView
        if let existing = view.viewWithTag(backgroundImageTag) as? UIImageView {
            imageView = existing
        } else {
            imageView = UIImageView()
            imageView.tag = backgroundImageTag
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.isUserInteractionEnabled = false
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            view.insertSubview(imageView, at: 0)
            NSLayoutConstraint.activate([
                imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                imageView.topAnchor.constraint(equalTo: view.topAnchor),
                imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            ])
        }

        let colorOverlayView: UIView
        if let existing = view.viewWithTag(colorOverlayTag) {
            colorOverlayView = existing
        } else {
            colorOverlayView = UIView()
            colorOverlayView.tag = colorOverlayTag
            colorOverlayView.translatesAutoresizingMaskIntoConstraints = false
            colorOverlayView.isUserInteractionEnabled = false
            view.insertSubview(colorOverlayView, aboveSubview: imageView)
            NSLayoutConstraint.activate([
                colorOverlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                colorOverlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                colorOverlayView.topAnchor.constraint(equalTo: view.topAnchor),
                colorOverlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            ])
        }

        let patternView: UIView
        if let existing = view.viewWithTag(backgroundTag) {
            patternView = existing
        } else {
            patternView = UIView()
            patternView.tag = backgroundTag
            patternView.translatesAutoresizingMaskIntoConstraints = false
            patternView.isUserInteractionEnabled = false
            view.insertSubview(patternView, aboveSubview: colorOverlayView)
            NSLayoutConstraint.activate([
                patternView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                patternView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                patternView.topAnchor.constraint(equalTo: view.topAnchor),
                patternView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            ])
        }

        let overlayView: UIView
        if let existing = view.viewWithTag(readabilityOverlayTag) {
            overlayView = existing
        } else {
            overlayView = UIView()
            overlayView.tag = readabilityOverlayTag
            overlayView.translatesAutoresizingMaskIntoConstraints = false
            overlayView.isUserInteractionEnabled = false
            view.insertSubview(overlayView, aboveSubview: patternView)
            NSLayoutConstraint.activate([
                overlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                overlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                overlayView.topAnchor.constraint(equalTo: view.topAnchor),
                overlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            ])
        }

        if let customBackground = modeBackgroundImage() {
            imageView.image = customBackground
            imageView.alpha = modeBackgroundAlpha
            imageView.isHidden = false
            applyBackgroundOverlays(
                colorOverlayView: colorOverlayView,
                dimmingOverlayView: overlayView,
                hasBackgroundImage: true
            )
            patternView.alpha = 0.1
        } else {
            imageView.image = nil
            imageView.isHidden = true
            colorOverlayView.backgroundColor = .clear
            patternView.alpha = 0.4
            overlayView.backgroundColor = .clear
        }

        if let cached = cachedPatterns[current] {
            patternView.backgroundColor = UIColor(patternImage: cached)
        } else {
            let image = makePatternImage(dotColor: palette.dot, background: .clear)
            cachedPatterns[current] = image
            patternView.backgroundColor = UIColor(patternImage: image)
        }
    }

    static func applyBackgroundOverlays(
        colorOverlayView: UIView,
        dimmingOverlayView: UIView,
        hasBackgroundImage: Bool
    ) {
        guard hasBackgroundImage else {
            colorOverlayView.backgroundColor = .clear
            dimmingOverlayView.backgroundColor = .clear
            return
        }

        let palette = palette()
        let colorAlpha = effectiveThemeColorOverlayAlpha(for: palette)
        colorOverlayView.backgroundColor = palette.accent.withAlphaComponent(colorAlpha)
        dimmingOverlayView.backgroundColor = UIColor.black.withAlphaComponent(readabilityOverlayAlpha)
    }

    static func applyNavigationAppearance(to navigationController: UINavigationController?) {
        guard let navigationController else { return }
        let palette = palette()
        navigationController.navigationBar.tintColor = palette.text
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = palette.surface
        appearance.titleTextAttributes = [
            .foregroundColor: palette.text,
            .font: FontManager.font(.navigationTitle, weight: .bold)
        ]
        let barAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: palette.text,
            .font: FontManager.font(.small, size: 14, weight: .bold)
        ]
        appearance.shadowColor = palette.border
        let buttonBackgroundColor = palette.accent
        let buttonHighlightColor = palette.accentStrong
        let buttonAppearance = UIBarButtonItemAppearance()
        buttonAppearance.normal.titleTextAttributes = barAttributes
        buttonAppearance.highlighted.titleTextAttributes = barAttributes
        let normalImage = ThemeManager.makeRoundedImage(color: buttonBackgroundColor, cornerRadius: 16, size: CGSize(width: 88, height: 38))
        let highlightedImage = ThemeManager.makeRoundedImage(color: buttonHighlightColor, cornerRadius: 16, size: CGSize(width: 88, height: 38))
        buttonAppearance.normal.backgroundImage = normalImage
        buttonAppearance.highlighted.backgroundImage = highlightedImage
        buttonAppearance.normal.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: -1)
        buttonAppearance.highlighted.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: -1)
        appearance.buttonAppearance = buttonAppearance
        appearance.doneButtonAppearance = buttonAppearance
        appearance.backButtonAppearance = buttonAppearance
        navigationController.navigationBar.standardAppearance = appearance
        navigationController.navigationBar.scrollEdgeAppearance = appearance
        navigationController.navigationBar.compactAppearance = appearance
        navigationController.navigationBar.tintColor = palette.text
    }

    private static func makeRoundedImage(color: UIColor, cornerRadius: CGFloat, size: CGSize) -> UIImage? {
        let rect = CGRect(origin: .zero, size: size)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
        color.setFill()
        path.fill()
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        let cap = max(6, cornerRadius + 1)
        let insets = UIEdgeInsets(top: cap, left: cap, bottom: cap, right: cap)
        return image?.resizableImage(withCapInsets: insets, resizingMode: .stretch)
    }

    static func applySearchBar(_ searchBar: UISearchBar) {
        let palette = palette()
        searchBar.searchTextField.backgroundColor = palette.surface
        searchBar.searchTextField.textColor = palette.text
        searchBar.searchTextField.font = AppFont.jp(size: 14)
        searchBar.searchTextField.layer.cornerRadius = 12
        searchBar.searchTextField.layer.borderWidth = 1
        searchBar.searchTextField.layer.borderColor = palette.border.cgColor
        searchBar.searchTextField.clipsToBounds = true
        searchBar.tintColor = palette.text
    }

    static func stylePrimaryButton(_ button: UIButton) {
        let palette = palette()
        applyThemeButtonStyle(button, palette: palette, cornerRadius: 18, shadowOpacity: 0.22)
        button.applyMankiButtonMetrics()
    }

    static func styleSecondaryButton(_ button: UIButton) {
        let palette = palette()
        applyThemeButtonStyle(button, palette: palette, cornerRadius: 18, shadowOpacity: 0.12)
        button.applyMankiButtonMetrics()
    }

    static func stylePixelIconButton(_ button: UIButton) {
        let palette = palette()
        let normalBackground = palette.surface.withAlphaComponent(0.96)
        let highlightedBackground = palette.accent.withAlphaComponent(0.9)
        button.configurationUpdateHandler = { button in
            let isPressed = button.isHighlighted
            button.backgroundColor = isPressed ? highlightedBackground : normalBackground
            button.tintColor = palette.text
            applyRetroButtonPressState(
                button,
                isPressed: isPressed,
                shadowColor: palette.border.cgColor,
                shadowOpacity: 0.18
            )
        }
        button.tintColor = palette.text
        button.backgroundColor = normalBackground
        button.layer.cornerRadius = 18
        button.layer.borderWidth = 2
        button.layer.borderColor = palette.border.cgColor
        button.clipsToBounds = false
        button.imageView?.contentMode = .scaleAspectFit
        applyRetroButtonPressState(button, isPressed: false, shadowColor: palette.border.cgColor, shadowOpacity: 0.18)
        button.setNeedsUpdateConfiguration()
    }

    static func stylePixelOutlineButton(_ button: UIButton, selected: Bool = false) {
        let palette = palette()
        let normalColor = selected ? palette.accent : palette.surfaceAlt
        let highlightedColor = normalColor.blended(with: .black, amount: 0.12)
        button.configurationUpdateHandler = { button in
            let isPressed = button.isHighlighted
            button.backgroundColor = isPressed ? highlightedColor : normalColor
            button.tintColor = palette.text
            button.setTitleColor(palette.text, for: .normal)
            applyRetroButtonPressState(
                button,
                isPressed: isPressed,
                shadowColor: palette.border.cgColor,
                shadowOpacity: selected ? 0.18 : 0.1
            )
        }
        button.backgroundColor = normalColor
        button.tintColor = palette.text
        button.setTitleColor(palette.text, for: .normal)
        button.titleLabel?.font = AppFont.jp(size: 14, weight: .bold)
        button.titleLabel?.numberOfLines = 1
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.layer.cornerRadius = 18
        button.layer.borderWidth = selected ? 2 : 1.5
        button.layer.borderColor = palette.border.cgColor
        button.clipsToBounds = false
        applyRetroButtonPressState(button, isPressed: false, shadowColor: palette.border.cgColor, shadowOpacity: selected ? 0.18 : 0.1)
        button.setNeedsUpdateConfiguration()
    }

    static func styleCard(_ view: UIView, fillColor: UIColor? = nil) {
        let palette = palette()
        view.backgroundColor = fillColor ?? palette.surface
        view.layer.cornerRadius = AppLayout.cardCornerRadius
        view.layer.borderWidth = 1
        view.layer.borderColor = palette.border.cgColor
        view.layer.shadowColor = palette.border.cgColor
        view.layer.shadowOpacity = 0.08
        view.layer.shadowOffset = CGSize(width: 0, height: 6)
        view.layer.shadowRadius = 12
    }

    private static func makePatternImage(dotColor: UIColor, background: UIColor) -> UIImage {
        let size = CGSize(width: 14, height: 14)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            background.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            dotColor.setFill()
            let dotRect = CGRect(x: 6, y: 6, width: 2, height: 2)
            context.cgContext.fillEllipse(in: dotRect)
        }
    }

    private static func modeBackgroundFileURL() -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(modeBackgroundFileName)
    }

    private static func effectiveThemeColorOverlayAlpha(for palette: ThemePalette) -> CGFloat {
        var alpha = themeColorOverlayAlpha
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var colorAlpha: CGFloat = 0

        if palette.accent.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &colorAlpha) {
            if brightness > 0.78 && saturation > 0.45 {
                alpha -= 0.04
            }
            if brightness < 0.55 {
                alpha -= 0.02
            }
        }

        if readabilityOverlayAlpha > 0.35 {
            alpha -= 0.03
        }

        return min(max(alpha, 0.08), 0.24)
    }

    private static func applyThemeButtonStyle(
        _ button: UIButton,
        palette: ThemePalette,
        cornerRadius: CGFloat,
        shadowOpacity: Float
    ) {
        let initialTitle = button.title(for: .normal)
        let initialImage = button.image(for: .normal)
        let fillColor = readableButtonFillColor(for: palette)
        let highlightedColor = fillColor.blended(with: .black, amount: 0.14)
        let disabledColor = fillColor.withAlphaComponent(0.42)

        button.configurationUpdateHandler = { button in
            var configuration = UIButton.Configuration.filled()
            configuration.title = button.title(for: .normal) ?? button.configuration?.title ?? initialTitle
            configuration.image = button.image(for: .normal) ?? button.configuration?.image ?? initialImage
            configuration.imagePlacement = .leading
            configuration.imagePadding = 6
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 18, bottom: 12, trailing: 18)
            configuration.cornerStyle = .fixed
            configuration.background.cornerRadius = cornerRadius
            configuration.baseForegroundColor = button.isEnabled ? .white : UIColor.white.withAlphaComponent(0.72)

            if !button.isEnabled {
                configuration.baseBackgroundColor = disabledColor
            } else if button.isHighlighted {
                configuration.baseBackgroundColor = highlightedColor
            } else {
                configuration.baseBackgroundColor = fillColor
            }

            button.configuration = configuration
            applyRetroButtonPressState(
                button,
                isPressed: button.isHighlighted && button.isEnabled,
                shadowColor: palette.border.cgColor,
                shadowOpacity: shadowOpacity
            )
        }

        button.backgroundColor = fillColor
        button.tintColor = .white
        button.setTitleColor(.white, for: .normal)
        button.setTitleColor(UIColor.white.withAlphaComponent(0.78), for: .highlighted)
        button.titleLabel?.font = AppFont.jp(size: 15, weight: .bold)
        button.layer.cornerRadius = cornerRadius
        button.layer.borderWidth = 2
        button.layer.borderColor = palette.border.withAlphaComponent(0.9).cgColor
        button.clipsToBounds = false
        applyRetroButtonPressState(button, isPressed: false, shadowColor: palette.border.cgColor, shadowOpacity: shadowOpacity)
        button.setNeedsUpdateConfiguration()
    }

    private static func applyRetroButtonPressState(
        _ button: UIButton,
        isPressed: Bool,
        shadowColor: CGColor,
        shadowOpacity: Float
    ) {
        let transform = isPressed ? CGAffineTransform(translationX: 0, y: 3) : .identity
        let shadowOffset = isPressed ? CGSize(width: 0, height: 1) : CGSize(width: 0, height: 4)
        let currentOpacity = isPressed ? max(0.08, shadowOpacity * 0.75) : shadowOpacity

        if UIView.areAnimationsEnabled {
            UIView.animate(withDuration: 0.08, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction]) {
                button.transform = transform
            }
        } else {
            button.transform = transform
        }

        button.layer.shadowColor = shadowColor
        button.layer.shadowOpacity = currentOpacity
        button.layer.shadowOffset = shadowOffset
        button.layer.shadowRadius = 0
    }

    private static func readableButtonFillColor(for palette: ThemePalette) -> UIColor {
        var color = palette.accentStrong
        if color.relativeLuminance > 0.34 {
            color = color.blended(with: .black, amount: 0.22)
        }
        if color.relativeLuminance > 0.34 {
            color = color.blended(with: .black, amount: 0.18)
        }
        return color
    }
}

private extension UIColor {
    convenience init(hex: Int, alpha: CGFloat = 1.0) {
        let red = CGFloat((hex >> 16) & 0xFF) / 255.0
        let green = CGFloat((hex >> 8) & 0xFF) / 255.0
        let blue = CGFloat(hex & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }

    var relativeLuminance: CGFloat {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return 0.2126 * red + 0.7152 * green + 0.0722 * blue
    }

    func blended(with color: UIColor, amount: CGFloat) -> UIColor {
        var red1: CGFloat = 0
        var green1: CGFloat = 0
        var blue1: CGFloat = 0
        var alpha1: CGFloat = 0
        var red2: CGFloat = 0
        var green2: CGFloat = 0
        var blue2: CGFloat = 0
        var alpha2: CGFloat = 0
        getRed(&red1, green: &green1, blue: &blue1, alpha: &alpha1)
        color.getRed(&red2, green: &green2, blue: &blue2, alpha: &alpha2)
        let clamped = min(max(amount, 0), 1)
        return UIColor(
            red: red1 + (red2 - red1) * clamped,
            green: green1 + (green2 - green1) * clamped,
            blue: blue1 + (blue2 - blue1) * clamped,
            alpha: alpha1 + (alpha2 - alpha1) * clamped
        )
    }
}
