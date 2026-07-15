import SwiftUI

struct CanvasRoute {
    let path: Path
    let arrowFrom: CGPoint
    let arrowTo: CGPoint
    let labelPoint: CGPoint
}

private func cardRect(_ node: DiagramNode) -> CGRect {
    // Matches the card's fixed width and reserves enough vertical room for fields.
    CGRect(x: node.position.x, y: node.position.y, width: 148, height: max(104, 62 + CGFloat(node.fields.count) * 20))
}

private func hits(_ from: CGPoint, _ to: CGPoint, _ rect: CGRect) -> Bool {
    // Sampling is reliable here because cards are small, axis-aligned obstacles.
    for step in 0...32 {
        let t = CGFloat(step) / 32
        if rect.contains(CGPoint(x: from.x + (to.x - from.x) * t, y: from.y + (to.y - from.y) * t)) { return true }
    }
    return false
}

func canvasRoute(from source: DiagramNode, to target: DiagramNode, all nodes: [DiagramNode]) -> CanvasRoute {
    let sourceRect = cardRect(source), targetRect = cardRect(target)
    let dx = targetRect.midX - sourceRect.midX, dy = targetRect.midY - sourceRect.midY
    let horizontal = abs(dx) >= abs(dy)
    let start = horizontal ? CGPoint(x: dx >= 0 ? sourceRect.maxX : sourceRect.minX, y: sourceRect.midY) : CGPoint(x: sourceRect.midX, y: dy >= 0 ? sourceRect.maxY : sourceRect.minY)
    let end = horizontal ? CGPoint(x: dx >= 0 ? targetRect.minX : targetRect.maxX, y: targetRect.midY) : CGPoint(x: targetRect.midX, y: dy >= 0 ? targetRect.minY : targetRect.maxY)
    let obstacles = nodes.filter { $0.id != source.id && $0.id != target.id }.map(cardRect).map { $0.insetBy(dx: -22, dy: -22) }
    let blocked = obstacles.contains { hits(start, end, $0) }
    var path = Path(); path.move(to: start)
    if !blocked {
        let c1 = horizontal ? CGPoint(x: start.x + (end.x - start.x) * 0.42, y: start.y) : CGPoint(x: start.x, y: start.y + (end.y - start.y) * 0.42)
        let c2 = horizontal ? CGPoint(x: end.x - (end.x - start.x) * 0.42, y: end.y) : CGPoint(x: end.x, y: end.y - (end.y - start.y) * 0.42)
        path.addCurve(to: end, control1: c1, control2: c2)
        return CanvasRoute(path: path, arrowFrom: c2, arrowTo: end, labelPoint: CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2 - 14))
    }
    if horizontal {
        let top = min(sourceRect.minY, targetRect.minY, obstacles.map(\.minY).min() ?? .greatestFiniteMagnitude) - 34
        let bottom = max(sourceRect.maxY, targetRect.maxY, obstacles.map(\.maxY).max() ?? -.greatestFiniteMagnitude) + 34
        let laneY = abs(start.y - top) <= abs(bottom - start.y) ? top : bottom
        let first = CGPoint(x: start.x + (dx >= 0 ? 42 : -42), y: laneY)
        let second = CGPoint(x: end.x - (dx >= 0 ? 42 : -42), y: laneY)
        path.addCurve(to: first, control1: .init(x: start.x + (dx >= 0 ? 26 : -26), y: start.y), control2: .init(x: first.x, y: first.y + (start.y > laneY ? 18 : -18)))
        path.addLine(to: second)
        path.addCurve(to: end, control1: .init(x: second.x, y: second.y + (end.y > laneY ? 18 : -18)), control2: .init(x: end.x - (dx >= 0 ? 26 : -26), y: end.y))
        return CanvasRoute(path: path, arrowFrom: second, arrowTo: end, labelPoint: CGPoint(x: (first.x + second.x) / 2, y: laneY - 14))
    }
    let left = min(sourceRect.minX, targetRect.minX, obstacles.map(\.minX).min() ?? .greatestFiniteMagnitude) - 34
    let right = max(sourceRect.maxX, targetRect.maxX, obstacles.map(\.maxX).max() ?? -.greatestFiniteMagnitude) + 34
    let laneX = abs(start.x - left) <= abs(right - start.x) ? left : right
    let first = CGPoint(x: laneX, y: start.y + (dy >= 0 ? 42 : -42))
    let second = CGPoint(x: laneX, y: end.y - (dy >= 0 ? 42 : -42))
    path.addCurve(to: first, control1: .init(x: start.x, y: start.y + (dy >= 0 ? 26 : -26)), control2: .init(x: first.x + (start.x > laneX ? 18 : -18), y: first.y))
    path.addLine(to: second)
    path.addCurve(to: end, control1: .init(x: second.x + (end.x > laneX ? 18 : -18), y: second.y), control2: .init(x: end.x, y: end.y - (dy >= 0 ? 26 : -26)))
    return CanvasRoute(path: path, arrowFrom: second, arrowTo: end, labelPoint: CGPoint(x: laneX, y: (first.y + second.y) / 2 - 14))
}
