/// Random selection without repeats: every element is shown once
/// (in random order) before any element is shown again.
struct ShuffleBag<Element: Equatable> {
    private var allElements: [Element]
    private var remainingElements: [Element] = []
    private var lastDrawnElement: Element?

    init(elements: [Element]) {
        allElements = elements
    }

    var isEmpty: Bool { allElements.isEmpty }

    mutating func drawNext() -> Element? {
        guard !allElements.isEmpty else { return nil }

        if remainingElements.isEmpty {
            refillAvoidingImmediateRepeat()
        }

        let drawnElement = remainingElements.popLast()
        lastDrawnElement = drawnElement
        return drawnElement
    }

    /// Reshuffles the bag
    private mutating func refillAvoidingImmediateRepeat() {
        remainingElements = allElements.shuffled()

        let wouldRepeatLastElement = remainingElements.count > 1 && remainingElements.last == lastDrawnElement
        if wouldRepeatLastElement {
            remainingElements.swapAt(0, remainingElements.count - 1)
        }
    }
}
