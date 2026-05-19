import SwiftUI

struct AdMobBannerView: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.cosmicCyan)

            VStack(alignment: .leading, spacing: 3) {
                Text("COSMIC SIGNAL")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundColor(.starAmber)

                Text("SynthMaker Techno")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.panelText)
            }

            Spacer()

            HStack(spacing: 4) {
                ForEach(0..<8, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(index.isMultiple(of: 3) ? Color.starAmber : Color.cosmicCyan.opacity(0.72))
                        .frame(width: 5, height: CGFloat(12 + index % 4 * 5))
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .frame(height: 72)
        .background(
            LinearGradient(
                colors: [
                    Color.black,
                    Color(red: 0.02, green: 0.05, blue: 0.07)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1),
            alignment: .top
        )
    }
}
