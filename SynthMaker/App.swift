import SwiftUI
import GoogleMobileAds

@main
struct SynthMakerApp: App {
    init() {
        MobileAds.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
