import InkletCore
import SwiftUI

struct PlayingSpeakerIcon: View {
    let fontSize: CGFloat
    let weight: Font.Weight

    var body: some View {
        SpeakerWaveIcon(state: .playing, fontSize: fontSize, weight: weight)
    }
}

struct SpeakerWaveIcon: View {
    enum PlaybackState {
        case idle
        case playing
    }

    @State private var startedAt = Date()

    let state: PlaybackState
    let fontSize: CGFloat
    let weight: Font.Weight
    var isFilled = false
    var foregroundColor = InkletTheme.textPrimary

    var body: some View {
        Group {
            switch state {
            case .idle:
                icon(bracketCount: SpeakerWaveIconSequence.idleBracketCount)
            case .playing:
                TimelineView(.periodic(from: startedAt, by: SpeakerWaveIconSequence.frameDuration)) { context in
                    let elapsedTime = context.date.timeIntervalSince(startedAt)
                    icon(bracketCount: SpeakerWaveIconSequence.bracketCount(atElapsedTime: elapsedTime))
                }
            }
        }
        .onAppear {
            startedAt = Date()
        }
    }

    private func icon(bracketCount: Int) -> some View {
        ZStack {
            Image(systemName: speakerSystemImageName)
                .font(.system(size: fontSize, weight: weight))
                .foregroundStyle(foregroundColor)

            ZStack {
                ForEach(0..<3) { bracketIndex in
                    SpeakerBracketShape(index: bracketIndex)
                        .stroke(
                            foregroundColor.opacity(bracketIndex < bracketCount ? 0.72 : 0),
                            style: StrokeStyle(
                                lineWidth: max(1, fontSize * 0.09),
                                lineCap: .round
                            )
                        )
                }
            }
            .frame(width: fontSize * 0.80, height: fontSize * 0.95)
            .offset(x: fontSize * 0.62)
            .animation(
                .easeInOut(duration: SpeakerWaveIconSequence.frameDuration * 0.55),
                value: bracketCount
            )
            .allowsHitTesting(false)
        }
    }

    private var speakerSystemImageName: String {
        let baseName = SpeakerWaveIconSequence.stableSystemImageName
        return isFilled ? "\(baseName).fill" : baseName
    }
}

private struct SpeakerBracketShape: Shape {
    let index: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.minX, y: rect.midY)
        let radius = min(rect.width, rect.height) * (0.22 + CGFloat(index) * 0.18)

        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(-39),
            endAngle: .degrees(39),
            clockwise: false
        )
        return path
    }
}
