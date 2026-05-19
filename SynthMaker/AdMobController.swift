import AppTrackingTransparency
import Combine
import Foundation

final class AdMobController: ObservableObject {
    @Published private(set) var isReady = true

    private var didRequestTracking = false

    func startIfNeeded() {
        DispatchQueue.main.async { [weak self] in
            self?.requestTrackingIfNeeded()
        }
    }

    private func requestTrackingIfNeeded() {
        guard !didRequestTracking else { return }
        didRequestTracking = true

        guard #available(iOS 14, *) else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            ATTrackingManager.requestTrackingAuthorization { _ in }
        }
    }
}
