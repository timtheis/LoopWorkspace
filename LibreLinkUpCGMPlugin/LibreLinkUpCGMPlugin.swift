import Foundation
import LoopKitUI

class LibreLinkUpCGMPlugin: NSObject, CGMManagerUIPlugin {
    public var cgmManagerType: CGMManagerUI.Type? {
        return LibreLinkUpManager.self
    }
}