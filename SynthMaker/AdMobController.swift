import AppTrackingTransparency
import Foundation
import GoogleMobileAds

final class AdMobController: ObservableObject {
    @Published private(set) var isReady = false

    private var didStart = false

    func startIfNeeded() {
        DispatchQueue.main.async { [weak self] in
            self?.startOnMainThread()
        }
    }

    private func startOnMainThread() {
        guard !didStart else { return }
        didStart = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.requestTrackingThenStartAds()
        }
    }

    private func requestTrackingThenStartAds() {
        if #available(iOS 14, *) {
            ATTrackingManager.requestTrackingAuthorization { [weak self] _ in
                self?.startAdsOnMainThread()
            }
        } else {
            startAdsOnMainThread()
        }
    }

    private func startAdsOnMainThread() {
        DispatchQueue.main.async { [weak self] in
            MobileAds.shared.start { _ in
                DispatchQueue.main.async {
                    self?.isReady = true
                }
            }
        }
    }
}
