import AppTrackingTransparency
import Foundation
import GoogleMobileAds

final class AdMobController: ObservableObject {
    @Published private(set) var isReady = false

    private var didStart = false

    func startIfNeeded() {
        guard !didStart else { return }
        didStart = true

        let startAds = { [weak self] in
            MobileAds.shared.start { _ in
                DispatchQueue.main.async {
                    self?.isReady = true
                }
            }
        }

        if #available(iOS 14, *) {
            ATTrackingManager.requestTrackingAuthorization { _ in
                startAds()
            }
        } else {
            startAds()
        }
    }
}
