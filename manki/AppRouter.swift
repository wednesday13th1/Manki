import UIKit

enum AppRoute: CaseIterable {
    case home
    case music
    case sets
    case test
    case record
    case settings
    case folder
    case playlists
    case flip

    static let menuRoutes: [AppRoute] = [.home, .music, .sets, .test, .record, .settings]

    var title: String {
        switch self {
        case .home: return "Home"
        case .music: return "Music"
        case .sets: return "Study"
        case .test: return "Test"
        case .record: return "Record"
        case .settings: return "Settings"
        case .folder: return "Folder"
        case .playlists: return "Playlist"
        case .flip: return "Flip"
        }
    }

    var systemImageName: String {
        switch self {
        case .home: return "house.fill"
        case .music: return "music.note.list"
        case .sets: return "book.fill"
        case .test: return "checkmark.circle.fill"
        case .record: return "calendar"
        case .settings: return "gearshape.fill"
        case .folder: return "folder.fill"
        case .playlists: return "music.note.list"
        case .flip: return "rectangle.on.rectangle.angled.fill"
        }
    }

    var isPrimaryMenuRoute: Bool {
        AppRoute.menuRoutes.contains(self)
    }
}

extension AppRoute {
    static var allCases: [AppRoute] {
        [.home, .music, .sets, .test, .record, .settings, .folder, .playlists, .flip]
    }
}

extension AppRoute {
    static func route(for viewController: UIViewController?) -> AppRoute? {
        guard let viewController else { return nil }
        switch viewController {
        case is ModeViewController:
            return .home
        case is MusicViewController, is LyricsViewController:
            return .music
        case is FolderViewController:
            return .folder
        case is SetViewController:
            return .sets
        case is PlaylistListViewController, is PlaylistDetailViewController, is PlaylistSongViewController, is PlaylistEditorViewController:
            return .playlists
        case is FlipViewController:
            return .flip
        case is TestViewController, is QuizViewController:
            return .test
        case is HistoryViewController, is ResultViewController:
            return .record
        case is SettingViewController:
            return .settings
        default:
            return nil
        }
    }
}

enum AppRouter {
    static func makeViewController(for route: AppRoute, storyboard: UIStoryboard?) -> UIViewController {
        let storyboard = storyboard ?? UIStoryboard(name: "Main", bundle: nil)
        switch route {
        case .home:
            return storyboard.instantiateInitialViewController() ?? ModeViewController()
        case .music:
            return MusicViewController()
        case .sets:
            return SetViewController(folderID: nil, showsAll: true)
        case .test:
            return TestViewController()
        case .record:
            return HistoryViewController()
        case .settings:
            return SettingViewController()
        case .folder:
            return storyboard.instantiateViewController(withIdentifier: "FolderViewController")
        case .flip:
            return storyboard.instantiateViewController(withIdentifier: "FlipViewController")
        case .playlists:
            return PlaylistListViewController()
        }
    }

    static func navigate(to route: AppRoute, from navigationController: UINavigationController) {
        if route == .home {
            navigationController.dismiss(animated: true)
            return
        }

        if let existing = navigationController.viewControllers.first(where: { AppRoute.route(for: $0) == route }) {
            navigationController.popToViewController(existing, animated: true)
            return
        }

        let controller = makeViewController(for: route, storyboard: navigationController.storyboard)
        prepare(controller, in: navigationController)
        navigationController.setViewControllers([controller], animated: false)
    }

    static func push(_ controller: UIViewController, from navigationController: UINavigationController, animated: Bool = true) {
        prepare(controller, in: navigationController)
        navigationController.pushViewController(controller, animated: animated)
    }

    private static func prepare(_ controller: UIViewController, in navigationController: UINavigationController) {
        if let setController = controller as? SetViewController {
            setController.prepareForInitialTransition(in: navigationController.view.bounds)
        } else {
            controller.loadViewIfNeeded()
            controller.view.frame = navigationController.view.bounds
        }
    }
}

extension AppRoute {
    func menuIcon(tintColor: UIColor) -> UIImage? {
        let configuration = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold, scale: .medium)
        return UIImage(systemName: systemImageName, withConfiguration: configuration)?
            .withTintColor(tintColor, renderingMode: .alwaysOriginal)
    }
}
