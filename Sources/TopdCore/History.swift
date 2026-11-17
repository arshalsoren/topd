import Foundation

/// Fixed-length window of recent samples, oldest first.
public struct History: Equatable, Sendable {
    public let capacity: Int
    public private(set) var values: [Double] = []

    public init(capacity: Int) {
        self.capacity = capacity
    }

    public mutating func append(_ value: Double) {
        values.append(value)
        if values.count > capacity {
            values.removeFirst(values.count - capacity)
        }
    }
}
