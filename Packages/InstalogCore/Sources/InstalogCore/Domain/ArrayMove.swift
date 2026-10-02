import Foundation

public extension Array {
    /// Same semantics as SwiftUI's `move(fromOffsets:toOffset:)`, without depending on SwiftUI.
    func moving(fromOffsets source: IndexSet, toOffset destination: Int) -> [Element] {
        let moved = source.map { self[$0] }
        var remaining: [Element] = []
        var insertAt = destination
        for (index, element) in enumerated() {
            if source.contains(index) {
                if index < destination { insertAt -= 1 }
            } else {
                remaining.append(element)
            }
        }
        remaining.insert(contentsOf: moved, at: Swift.min(Swift.max(insertAt, 0), remaining.count))
        return remaining
    }
}
