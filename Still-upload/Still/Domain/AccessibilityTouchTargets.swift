import Foundation

/// Geometry contracts shared by the SwiftUI layer and the platform-neutral
/// test suite. 44pt is the smallest direct target Still permits; a compact
/// device may scroll a puzzle board horizontally, but it never shrinks a cell
/// below this size.
enum AccessibilityTouchTarget {
    static let minimumSide: Double = 44

    static func squareGridSpan(columns: Int, gap: Double) -> Double {
        guard columns > 0 else { return 0 }
        return (Double(columns) * minimumSide) + (Double(columns - 1) * gap)
    }

    static func sudokuGridSpan(
        size: Int,
        boxColumns: Int,
        cellGap: Double,
        boxGap: Double,
        boxPadding: Double
    ) -> Double {
        guard size > 0, boxColumns > 0, size.isMultiple(of: boxColumns) else { return 0 }
        let cellsPerBox = Double(boxColumns) * minimumSide
        let gapsPerBox = Double(boxColumns - 1) * cellGap
        let oneBox = cellsPerBox + gapsPerBox + (boxPadding * 2)
        let boxes = size / boxColumns
        return (Double(boxes) * oneBox) + (Double(boxes - 1) * boxGap)
    }

    static func picrossGridSpan(size: Int, clueColumn: Double, gap: Double) -> Double {
        guard size > 0 else { return clueColumn }
        // One gap separates the clue column from the first cell; the remaining
        // gaps separate adjacent cells.
        return clueColumn + (Double(size) * minimumSide) + (Double(size) * gap)
    }

    static func meetsMinimum(width: Double, height: Double) -> Bool {
        width >= minimumSide && height >= minimumSide
    }
}
