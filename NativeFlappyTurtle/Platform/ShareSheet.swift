import UIKit

/// The original shared to Facebook through the (now unbundled) FB SDK. The
/// native equivalent is the system share sheet with the same text and link.
final class ShareSheet: ScoreSharing {
    weak var presenter: UIViewController?

    func share(title: String, caption: String, description: String, link: String, picture: String) {
        guard let presenter, presenter.presentedViewController == nil else { return }
        var items: [Any] = ["\(description). \(caption)!"]
        if let url = URL(string: link) { items.append(url) }
        let sheet = UIActivityViewController(activityItems: items, applicationActivities: nil)
        sheet.setValue(title, forKey: "subject")
        sheet.popoverPresentationController?.sourceView = presenter.view
        sheet.popoverPresentationController?.sourceRect = CGRect(x: presenter.view.bounds.midX,
                                                                 y: presenter.view.bounds.midY,
                                                                 width: 0, height: 0)
        presenter.present(sheet, animated: true)
    }
}

/// Records share requests instead of showing UI (test hooks).
final class RecordingShareSheet: ScoreSharing {
    private(set) var lastDescription: String?

    func share(title: String, caption: String, description: String, link: String, picture: String) {
        lastDescription = description
    }
}
