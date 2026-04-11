import UIKit
import LoopKit
import LoopKitUI

final class LibreLinkUpSetupViewController: UINavigationController, CompletionNotifying, CGMManagerOnboarding {
    public weak var cgmManagerOnboardingDelegate: CGMManagerOnboardingDelegate?
    public weak var completionDelegate: CompletionDelegate?

    let cgmManager = LibreLinkUpManager()

    init() {
        let rootVC = UIViewController()
        rootVC.title = "Libre Setup"
        rootVC.view.backgroundColor = .systemBackground
        
        super.init(rootViewController: rootVC)
        
        let label = UILabel()
        label.text = "Libre LinkUp Direct\n\nTap 'Done' to complete the handshake."
        label.numberOfLines = 0
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        rootVC.view.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: rootVC.view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: rootVC.view.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: rootVC.view.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: rootVC.view.trailingAnchor, constant: -20)
        ])
        
        rootVC.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneTapped))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func doneTapped() {
        cgmManagerOnboardingDelegate?.cgmManagerOnboarding(didCreateCGMManager: cgmManager)
        cgmManagerOnboardingDelegate?.cgmManagerOnboarding(didOnboardCGMManager: cgmManager)
        completionDelegate?.completionNotifyingDidComplete(self)
    }
}

// Extension to bridge the UI to the Manager
extension LibreLinkUpManager: CGMManagerUI {
    public static func setupViewController(bluetoothProvider: BluetoothProvider, displayGlucosePreference: DisplayGlucosePreference, colorPalette: LoopUIColorPalette, allowDebugFeatures: Bool, prefersToSkipUserInteraction: Bool) -> SetupUIResult<CGMManagerViewController, CGMManagerUI> {
        return .userInteractionRequired(LibreLinkUpSetupViewController())
    }
    
    public func settingsViewController(bluetoothProvider: BluetoothProvider, displayGlucosePreference: DisplayGlucosePreference, colorPalette: LoopUIColorPalette, allowDebugFeatures: Bool) -> CGMManagerViewController {
        let rootVC = UIViewController()
        rootVC.title = "Libre Settings"
        rootVC.view.backgroundColor = .systemBackground
        let nav = CGMManagerSettingsNavigationViewController(rootViewController: rootVC)
        return nav
    }
    
    public var smallImage: UIImage? { return nil }
}