import UIKit
import SwiftUI

final class ShareExtensionViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        addChild(UIHostingController(rootView: CompanionShareImportView()))
    }
}
