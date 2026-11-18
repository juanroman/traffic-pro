import Foundation
import Testing

@testable import HomeCore

/// The cases `onMove` produces, matching SwiftUI's `move(fromOffsets:toOffset:)`.
struct ReorderTests {
  private func moved(_ source: [Int], to destination: Int) -> [Int] {
    var items = [0, 1, 2, 3, 4]
    items.reorder(fromOffsets: IndexSet(source), toOffset: destination)
    return items
  }

  @Test func movesOneElementDown() {
    #expect(moved([1], to: 4) == [0, 2, 3, 1, 4])
  }

  @Test func movesOneElementUp() {
    #expect(moved([3], to: 1) == [0, 3, 1, 2, 4])
  }

  @Test func movesToTheEnd() {
    #expect(moved([0], to: 5) == [1, 2, 3, 4, 0])
  }

  @Test func movesToTheStart() {
    #expect(moved([4], to: 0) == [4, 0, 1, 2, 3])
  }

  @Test func droppingOnItselfChangesNothing() {
    #expect(moved([2], to: 2) == [0, 1, 2, 3, 4])
    #expect(moved([2], to: 3) == [0, 1, 2, 3, 4])
  }

  @Test func movesSeveralElementsTogetherKeepingTheirOrder() {
    #expect(moved([0, 2], to: 4) == [1, 3, 0, 2, 4])
    #expect(moved([3, 4], to: 1) == [0, 3, 4, 1, 2])
  }
}
