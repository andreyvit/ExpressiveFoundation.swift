import Foundation
import ObjectiveC

public protocol ObserverType: class {
}

public struct Observation {
    private var observers: [ObserverType] = []

    public init() {}

    public mutating func add(observer: ObserverType) {
        observers.append(observer)
    }

    public mutating func unobserve() {
        observers = []
    }
}
