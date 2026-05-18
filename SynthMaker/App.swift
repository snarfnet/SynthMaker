import SwiftUI
import UIKit

@main
struct SynthMakerApp: App {
    @StateObject private var ads = AdMobController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(ads)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    ads.startIfNeeded()
                }
        }
    }
}
