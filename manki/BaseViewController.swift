import UIKit

class BaseViewController: UIViewController {
    private var themeObserver: NSObjectProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()
        configureBaseNavigation()
        applyBaseTheme()
        themeObserver = NotificationCenter.default.addObserver(
            forName: ThemeManager.didChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyBaseTheme()
        }
    }

    deinit {
        if let themeObserver {
            NotificationCenter.default.removeObserver(themeObserver)
        }
    }

    func configureBaseNavigation() {
        navigationItem.backButtonDisplayMode = .minimal
    }

    func applyBaseTheme() {
        ThemeManager.applyBackground(to: view)
        ThemeManager.applyNavigationAppearance(to: navigationController)
        FontManager.applyPixelFont(to: view)
    }
}
