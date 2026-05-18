import SwiftUI
import GoogleMobileAds

struct AdMobBannerView: View {
    @EnvironmentObject private var ads: AdMobController

    private let adUnitID = "ca-app-pub-9404799280370656/2276411215"

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 320)
            let adSize = largeAnchoredAdaptiveBanner(width: width)

            if ads.isReady {
                BannerContainer(
                    adUnitID: adUnitID,
                    adSize: adSize
                )
                .frame(width: width, height: adSize.size.height)
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 96)
    }
}

private struct BannerContainer: UIViewRepresentable {
    let adUnitID: String
    let adSize: AdSize

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: adSize)
        banner.adUnitID = adUnitID
        banner.load(Request())
        return banner
    }

    func updateUIView(_ banner: BannerView, context: Context) {
        banner.adSize = adSize
    }
}
