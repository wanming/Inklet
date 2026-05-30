public enum PenNibGeometry {
    public struct Point: Equatable, Sendable {
        public let x: Double
        public let y: Double

        public init(x: Double, y: Double) {
            self.x = x
            self.y = y
        }
    }

    public struct Path: Equatable, Sendable {
        public let points: [Point]
        public let isClosed: Bool

        public init(points: [Point], isClosed: Bool) {
            self.points = points
            self.isClosed = isClosed
        }
    }

    public static let paths: [Path] = [
        Path(points: [
            Point(x: 12, y: 19),
            Point(x: 19, y: 12),
            Point(x: 22, y: 15),
            Point(x: 15, y: 22),
            Point(x: 12, y: 19)
        ], isClosed: true),
        Path(points: [
            Point(x: 18, y: 13),
            Point(x: 16.5, y: 5.5),
            Point(x: 2, y: 2),
            Point(x: 5.5, y: 16.5),
            Point(x: 13, y: 18),
            Point(x: 18, y: 13)
        ], isClosed: true),
        Path(points: [
            Point(x: 2, y: 2),
            Point(x: 9.586, y: 9.586)
        ], isClosed: false)
    ]
}
