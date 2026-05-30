import InkletCore
import SwiftUI

struct PenNibShape: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24
        let origin = CGPoint(
            x: rect.midX - 12 * scale,
            y: rect.midY - 12 * scale
        )

        return Path { path in
            PenNibGeometry.paths.forEach { geometry in
                guard let firstPoint = geometry.points.first else {
                    return
                }

                path.move(to: point(from: firstPoint, origin: origin, scale: scale))
                geometry.points.dropFirst().forEach { point in
                    path.addLine(to: self.point(from: point, origin: origin, scale: scale))
                }
                if geometry.isClosed {
                    path.closeSubpath()
                }
            }
        }
    }

    private func point(from point: PenNibGeometry.Point, origin: CGPoint, scale: CGFloat) -> CGPoint {
        CGPoint(
            x: origin.x + point.x * scale,
            y: origin.y + point.y * scale
        )
    }
}
