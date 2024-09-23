import UIKit
import PassKit
import SwiftUI
import WMFComponents
import WMFData

@objc(WMFProfileCoordinator)
final class ProfileCoordinator: NSObject, Coordinator, ProfileCoordinatorDelegate {

    // MARK: Coordinator Protocol Properties

    var navigationController: UINavigationController

    weak var delegate: LogoutCoordinatorDelegate?

    // MARK: Properties

    let theme: Theme
    let dataStore: MWKDataStore

    private weak var viewModel: WMFProfileViewModel?
    
    private let donateSouce: DonateCoordinator.Source
    private let targetRects = WMFProfileViewTargetRects()
    private var donateCoordinator: DonateCoordinator?
    
    let username: String?
    let isExplore: Bool?


    // MARK: Lifecycle
    
    // Convenience method to output a Settings coordinator from Objective-C
    @objc static func profileCoordinatorForSettingsProfileButton(navigationController: UINavigationController, theme: Theme, dataStore: MWKDataStore, logoutDelegate: LogoutCoordinatorDelegate?, isExplore: Bool = true) -> ProfileCoordinator {
        return ProfileCoordinator(navigationController: navigationController, theme: theme, dataStore: dataStore, donateSouce: .settingsProfile, logoutDelegate: logoutDelegate, isExplore: isExplore)
    }

    init(navigationController: UINavigationController, theme: Theme, dataStore: MWKDataStore, donateSouce: DonateCoordinator.Source, logoutDelegate: LogoutCoordinatorDelegate?, isExplore: Bool = true) {
        self.navigationController = navigationController
        self.theme = theme
        self.donateSouce = donateSouce
        self.dataStore = dataStore
        self.username = dataStore.authenticationManager.authStatePermanentUsername
        self.delegate = logoutDelegate
        self.isExplore = isExplore
    }

    // MARK: Coordinator Protocol Methods

    @objc func start() {
        let isLoggedIn = dataStore.authenticationManager.authStateIsPermanent

        let pageTitle = WMFLocalizedString("profile-page-title-logged-out", value: "Account", comment: "Page title for non-logged in users")
        let localizedStrings =
            WMFProfileViewModel.LocalizedStrings(
                pageTitle: (isLoggedIn ? username : pageTitle) ?? pageTitle,
                doneButtonTitle: CommonStrings.doneTitle,
                notificationsTitle: WMFLocalizedString("profile-page-notification-title", value: "Notifications", comment: "Link to notifications page"),
                userPageTitle: WMFLocalizedString("profile-page-user-page-title", value: "User page", comment: "Link to user page"),
                talkPageTitle: WMFLocalizedString("profile-page-talk-page-title", value: "Talk page", comment: "Link to talk page"),
                watchlistTitle: WMFLocalizedString("profile-page-watchlist-title", value: "Watchlist", comment: "Link to watchlist"),
                logOutTitle: WMFLocalizedString("profile-page-logout", value: "Log out", comment: "Log out button"),
                donateTitle: WMFLocalizedString("profile-page-donate", value: "Donate", comment: "Link to donate"),
                settingsTitle: WMFLocalizedString("profile-page-settings", value: "Settings", comment: "Link to settings"),
                joinWikipediaTitle: WMFLocalizedString("profile-page-join-title", value: "Join Wikipedia / Log in", comment: "Link to sign up or sign in"),
                joinWikipediaSubtext: WMFLocalizedString("profile-page-join-subtext", value:"Sign up for a Wikipedia account to track your contributions, save articles offline, and sync across devices.", comment: "Information about signing in or up"),
                donateSubtext: WMFLocalizedString("profile-page-donate-subtext", value: "Or support Wikipedia with a donation to keep it free and accessible for everyone around the world.", comment: "Information about supporting Wikipedia through donations")
            )

        let inboxCount = try? dataStore.remoteNotificationsController.numberOfUnreadNotifications()

        let viewModel = WMFProfileViewModel(
            isLoggedIn: isLoggedIn,
            localizedStrings: localizedStrings,
            inboxCount: Int(truncating: inboxCount ?? 0),
            coordinatorDelegate: self
        )

        var profileView = WMFProfileView(viewModel: viewModel)
        profileView.donePressed = { [weak self] in
            self?.navigationController.dismiss(animated: true, completion: nil)
        }
        self.viewModel = viewModel
        let finalView = profileView.environmentObject(targetRects)
        let hostingController = UIHostingController(rootView: finalView)
        hostingController.modalPresentationStyle = .pageSheet

        if let sheetPresentationController = hostingController.sheetPresentationController {
            sheetPresentationController.detents = [.large()]
            sheetPresentationController.prefersGrabberVisible = false
        }

        navigationController.present(hostingController, animated: true, completion: nil)
    }

    // MARK: - ProfileCoordinatorDelegate Methods

    public func handleProfileAction(_ action: ProfileAction) {
        switch action {
        case .showNotifications:
            dismissProfile {
                self.showNotifications()
            }
        case .showSettings:
            dismissProfile {
                self.showSettings()
            }
        case .showDonate:
            // Purposefully not dismissing profile here. We need DonateCoordinator to fetch and present an action sheet first before dismissing profile.
            self.showDonate()
        case .showUserPage:
            dismissProfile {
                self.showUserPage()
            }
        case .showUserTalkPage:
            dismissProfile {
                self.showUserTalkPage()
            }
        case .showWatchlist:
            dismissProfile {
                self.showWatchlist()
            }
        case .login:
            dismissProfile {
                self.login()
            }
        case .logout:
            dismissProfile {
                self.logout()
            }
        }
    }

    private func dismissProfile(completion: @escaping () -> Void) {
        navigationController.dismiss(animated: true) {
            completion()
        }
    }

    private func showNotifications() {
        let notificationsCoordinator = NotificationsCoordinator(navigationController: navigationController, theme: theme, dataStore: dataStore)
        notificationsCoordinator.start()
    }

    private func showSettings() {
        let settingsCoordinator = SettingsCoordinator(navigationController: navigationController, theme: theme, dataStore: dataStore)
        settingsCoordinator.start()
    }

    func showDonate() {
        
        guard let viewModel else {
            return
        }
        
        let donateCoordinator = DonateCoordinator(navigationController: navigationController, donateButtonGlobalRect: targetRects.donateButtonFrame, source: donateSouce, dataStore: dataStore, theme: theme, setLoadingBlock: { isLoading in
            viewModel.isLoadingDonateConfigs = isLoading
        })
        
        donateCoordinator.start()
        
        // Note: DonateCoordinator needs to handle a lot of delayed logic (fetch configs, present payment method action sheet, present native donate form and handle delegate callbacks from native donate form) as opposed to a fleeting navigation call with the other actions. For this reason we need to save it in a property so it isn't deallocated before this logic runs.
        self.donateCoordinator = donateCoordinator
    }
    

    private func showUserPage() {
        if let username, let siteURL = dataStore.primarySiteURL {
            let userPageCoordinator = UserPageCoordinator(navigationController: navigationController, theme: theme, username: username, siteURL: siteURL)
            userPageCoordinator.start()
        }
    }

    private func showUserTalkPage() {
        if let siteURL = dataStore.primarySiteURL, let username {
            let userTalkCoordinator = UserTalkCoordinator(navigationController: navigationController, theme: theme, username: username, siteURL: siteURL, dataStore: dataStore)
            userTalkCoordinator.start()
        }
    }

    private func showWatchlist() {
        let watchlistCoordinator = WatchlistCoordinator(navigationController: navigationController, dataStore: dataStore)
        watchlistCoordinator.start()
    }

    private func dismissProfile() {
        navigationController.dismiss(animated: true, completion: nil)
    }

    private func login() {
        let loginCoordinator = LoginCoordinator(navigationController: navigationController, theme: theme)
        loginCoordinator.start()
}

    private func logout() {
        let alertController = UIAlertController(title:CommonStrings.logoutAlertTitle, message: CommonStrings.logoutAlertMessage, preferredStyle: .alert)
        let logoutAction = UIAlertAction(title: CommonStrings.logoutTitle, style: .destructive) { [weak self] (action) in
            guard let self = self else {
                return
            }
            self.delegate?.didTapLogout()
        }
        let cancelAction = UIAlertAction(title: CommonStrings.cancelActionTitle, style: .cancel, handler: nil)
        alertController.addAction(logoutAction)
        alertController.addAction(cancelAction)
        navigationController.present(alertController, animated: true, completion: nil)
    }

}

