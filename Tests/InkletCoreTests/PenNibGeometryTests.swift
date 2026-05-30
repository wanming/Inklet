import XCTest
@testable import InkletCore

final class PenNibGeometryTests: XCTestCase {
    func testPathsMatchSuppliedSVGGeometry() {
        XCTAssertEqual(PenNibGeometry.paths, [
            .init(points: [
                .init(x: 12, y: 19),
                .init(x: 19, y: 12),
                .init(x: 22, y: 15),
                .init(x: 15, y: 22),
                .init(x: 12, y: 19)
            ], isClosed: true),
            .init(points: [
                .init(x: 18, y: 13),
                .init(x: 16.5, y: 5.5),
                .init(x: 2, y: 2),
                .init(x: 5.5, y: 16.5),
                .init(x: 13, y: 18),
                .init(x: 18, y: 13)
            ], isClosed: true),
            .init(points: [
                .init(x: 2, y: 2),
                .init(x: 9.586, y: 9.586)
            ], isClosed: false)
        ])
    }
}
