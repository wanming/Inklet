import Foundation

public enum SpeakerWaveIconSequence {
    public static let frameDuration: TimeInterval = 0.22
    public static let idleBracketCount = 2
    public static let stableSystemImageName = "speaker"

    private static let bracketCounts = [1, 2, 3, 2]

    public static func systemImageName(forFrame frame: Int) -> String {
        stableSystemImageName
    }

    public static func systemImageName(atElapsedTime elapsedTime: TimeInterval) -> String {
        stableSystemImageName
    }

    public static func bracketCount(forFrame frame: Int) -> Int {
        bracketCounts[wrappedIndex(forFrame: frame, count: bracketCounts.count)]
    }

    public static func bracketCount(atElapsedTime elapsedTime: TimeInterval) -> Int {
        let frame = Int(max(0, elapsedTime) / frameDuration)
        return bracketCount(forFrame: frame)
    }

    private static func wrappedIndex(forFrame frame: Int, count: Int) -> Int {
        ((frame % count) + count) % count
    }
}
