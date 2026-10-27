import XCTest
@testable import InkletCore

final class SelectionPanelPlacementTests: XCTestCase {
    func testPrefersBelowAndRightOfAnchorWithExtraGapWhenSpaceAllows() {
        let origin = SelectionPanelPlacement.origin(
            forPanelSize: SelectionPanelSize(width: 100, height: 50),
            near: SelectionPoint(x: 200, y: 200),
            in: SelectionScreenFrame(x: 0, y: 0, width: 500, height: 500)
        )

        XCTAssertEqual(origin, SelectionPoint(x: 218, y: 132))
    }

    func testUsesLeftSideWhenRightSideWouldLeaveVisibleFrame() {
        let origin = SelectionPanelPlacement.origin(
            forPanelSize: SelectionPanelSize(width: 100, height: 50),
            near: SelectionPoint(x: 470, y: 200),
            in: SelectionScreenFrame(x: 0, y: 0, width: 500, height: 500)
        )

        XCTAssertEqual(origin, SelectionPoint(x: 352, y: 132))
    }

    func testUsesAboveAnchorWhenBelowWouldLeaveVisibleFrame() {
        let origin = SelectionPanelPlacement.origin(
            forPanelSize: SelectionPanelSize(width: 100, height: 50),
            near: SelectionPoint(x: 200, y: 40),
            in: SelectionScreenFrame(x: 0, y: 0, width: 500, height: 500)
        )

        XCTAssertEqual(origin, SelectionPoint(x: 218, y: 58))
    }

    func testTranslationHeightFitsShortContentAndWidthGrowsForLongText() {
        let shortSize = SelectionPanelSizing.translationResultSize(textLength: 40) { _ in 78 }
        let longSize = SelectionPanelSizing.translationResultSize(textLength: 500) { _ in 200 }

        XCTAssertEqual(shortSize, SelectionPanelSize(width: 320, height: 78))
        XCTAssertEqual(longSize, SelectionPanelSize(width: 440, height: 200))
    }

    func testTranslationHeightIsMeasuredAtThePanelWidth() {
        var measuredWidths: [Double] = []
        _ = SelectionPanelSizing.translationResultSize(
            textLength: 40,
            rememberedSize: SelectionPanelSize(width: 480, height: 300)
        ) { width in
            measuredWidths.append(width)
            return 100
        }

        XCTAssertEqual(measuredWidths, [480])
    }

    func testTranslationHeightStaysBetweenTheMinimumAndTheDefaultMaximum() {
        let tiny = SelectionPanelSizing.translationResultSize(textLength: 1) { _ in 20 }
        let long = SelectionPanelSizing.translationResultSize(textLength: 2_000) { _ in 1_500 }

        XCTAssertEqual(tiny, SelectionPanelSize(width: 320, height: 72))
        XCTAssertEqual(long, SelectionPanelSize(width: 520, height: 360))
    }

    func testTranslationRememberedSizeSetsTheWidthAndHowTallThePanelMayGrow() {
        let remembered = SelectionPanelSize(width: 480, height: 300)
        let short = SelectionPanelSizing.translationResultSize(textLength: 40, rememberedSize: remembered) { _ in 78 }
        let long = SelectionPanelSizing.translationResultSize(textLength: 900, rememberedSize: remembered) { _ in 900 }

        XCTAssertEqual(short, SelectionPanelSize(width: 480, height: 78))
        XCTAssertEqual(long, SelectionPanelSize(width: 480, height: 300))
    }

    func testTranslationRememberedSizeIsClampedToTheResizeBounds() {
        let wide = SelectionPanelSizing.translationResultSize(
            textLength: 900,
            rememberedSize: SelectionPanelSize(width: 900, height: 900)
        ) { _ in 900 }
        let narrow = SelectionPanelSizing.translationResultSize(
            textLength: 900,
            rememberedSize: SelectionPanelSize(width: 100, height: 40)
        ) { _ in 900 }

        XCTAssertEqual(wide, SelectionPanelSize(width: 560, height: 520))
        XCTAssertEqual(narrow, SelectionPanelSize(width: 300, height: 72))
    }

    func testTranslationDragRegionAllowsToolbarBlankButExcludesTextAndButtons() {
        let regions = SelectionPanelDragRegions.translationResultRegions(
            panelSize: SelectionPanelSize(width: 440, height: 340)
        )

        XCTAssertTrue(regions.isBackgroundDragPoint(SelectionPoint(x: 220, y: 24)))
        XCTAssertFalse(regions.isBackgroundDragPoint(SelectionPoint(x: 40, y: 24)))
        XCTAssertFalse(regions.isBackgroundDragPoint(SelectionPoint(x: 370, y: 24)))
        XCTAssertFalse(regions.isBackgroundDragPoint(SelectionPoint(x: 220, y: 200)))
        XCTAssertFalse(regions.isBackgroundDragPoint(SelectionPoint(x: 4, y: 24)))
    }

    func testSelectionBarPressBecomesDragOnlyAfterThreshold() {
        let start = SelectionPoint(x: 100, y: 100)

        XCTAssertFalse(SelectionPanelDragRegions.hasPassedPressDragThreshold(from: start, to: start))
        XCTAssertFalse(SelectionPanelDragRegions.hasPassedPressDragThreshold(
            from: start,
            to: SelectionPoint(x: 102, y: 102)
        ))
        XCTAssertTrue(SelectionPanelDragRegions.hasPassedPressDragThreshold(
            from: start,
            to: SelectionPoint(x: 104, y: 100)
        ))
        XCTAssertTrue(SelectionPanelDragRegions.hasPassedPressDragThreshold(
            from: start,
            to: SelectionPoint(x: 97, y: 96)
        ))
    }
}
