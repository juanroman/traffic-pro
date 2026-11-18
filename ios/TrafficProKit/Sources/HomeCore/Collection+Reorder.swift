import Foundation

extension RangeReplaceableCollection {
  /// Moves the elements at `source` so they end up together before the element that is at
  /// `destination` now (or at the end when `destination == count`): the semantics of SwiftUI's
  /// `move(fromOffsets:toOffset:)`, which `onMove` hands us. Written here so this target does
  /// not need SwiftUI and can be linked by the watch app.
  mutating func reorder(fromOffsets source: IndexSet, toOffset destination: Int) {
    let moving = source.map { self[index(startIndex, offsetBy: $0)] }
    // Removing the moved elements shifts the destination left by those that sat before it.
    let shift = source.filter { $0 < destination }.count
    for offset in source.reversed() {
      remove(at: index(startIndex, offsetBy: offset))
    }
    insert(contentsOf: moving, at: index(startIndex, offsetBy: destination - shift))
  }
}
