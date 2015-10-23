import Foundation


// MARK: - Event

public protocol EventType {
    static var eventName: String { get }
}

public extension EventType {

    public static var eventName: String {
        return String(reflecting: self)
    }

    public var eventName: String {
        return self.dynamicType.eventName
    }

}


// MARK: - Emitter

public protocol EmitterType: class {

    var _listeners: EventListenerStorage { get set }

}

public extension EmitterType {

    public func emit<Event: EventType>(event: Event) {
        _listeners.emit(event)
    }

    @warn_unused_result
    public func subscribe<Event: EventType>(block: (Event, Self) -> Void) -> ListenerType {
        return BlockEventListener(self, block)
    }

    @warn_unused_result
    public func subscribe<Event: EventType, Target: AnyObject>(target: Target, _ block: (Target) -> (Event, Self) -> Void) -> ListenerType {
        return Method2ArgEventListener(self, target, block)
    }

    @warn_unused_result
    public func subscribe<Event: EventType, Target: AnyObject>(target: Target, _ block: (Target) -> (Event) -> Void) -> ListenerType {
        return Method1ArgEventListener(self, target, block)
    }

}


// MARK: - Storage

public struct EventListenerStorage {

    private var subscriptionsByEventType: [ObjectIdentifier: [EventSubscription]] = [:]

    public init() {
    }

    func emit<Event: EventType>(payload: Event) {
        let oid = ObjectIdentifier(Event.self)
        if let subscriptions = subscriptionsByEventType[oid] {
            for subscription in subscriptions {
                if subscription.listener?.eventType == Event.self {
                    if let listener = subscription.listener {
                        (listener as! EventListener<Event>).handle(payload)
                    }
                }
            }
        }
    }

    mutating func subscribe<Event: EventType>(listener: EventListener<Event>) {
        let oid = ObjectIdentifier(Event.self)
        let subscription = EventSubscription(listener)
        if subscriptionsByEventType[oid] != nil {
            subscriptionsByEventType[oid]!.append(subscription)
        } else {
            subscriptionsByEventType[oid] = [subscription]
        }
    }

    mutating func unsubscribe<Event: EventType>(listener: EventListener<Event>) {
        let oid = ObjectIdentifier(Event.self)
        if let subscriptions = subscriptionsByEventType[oid] {
            if let idx = subscriptions.indexOf({ $0.listener === listener }) {
                subscriptionsByEventType[oid]!.removeAtIndex(idx)
            }
        }
    }

}

private struct EventSubscription {

    private weak var listener: BaseEventListener?

    private init(_ listener: BaseEventListener) {
        self.listener = listener
    }

}


// MARK: - Listeners

class BaseEventListener: ListenerType {

    var eventType: EventType.Type {
        fatalError()
    }

}

class EventListener<Event: EventType>: BaseEventListener {

    override var eventType: EventType.Type {
        return Event.self
    }

    private weak var emitter: EmitterType?

    init(_ emitter: EmitterType) {
        self.emitter = emitter
        super.init()
        emitter._listeners.subscribe(self)
    }

    deinit {
        if let emitter = emitter {
            emitter._listeners.unsubscribe(self)
        }
    }

    func handle(payload: Event) {
        fatalError()
    }

}

private final class BlockEventListener<Event: EventType, Emitter: EmitterType>: EventListener<Event> {

    private let block: (Event, Emitter) -> Void

    init(_ emitter: Emitter, _ block: (Event, Emitter) -> Void) {
        self.block = block
        super.init(emitter)
    }

    override func handle(payload: Event) {
        block(payload, emitter as! Emitter)
    }

}

private final class Method2ArgEventListener<Event: EventType, Emitter: EmitterType, Target: AnyObject>: EventListener<Event> {

    private weak var target: Target?

    private let block: (Target) -> (Event, Emitter) -> Void

    init(_ emitter: Emitter, _ target: Target, _ block: (Target) -> (Event, Emitter) -> Void) {
        self.target = target
        self.block = block
        super.init(emitter)
    }

    override func handle(payload: Event) {
        if let target = target {
            block(target)(payload, emitter as! Emitter)
        }
    }
    
}

private final class Method1ArgEventListener<Event: EventType, Target: AnyObject>: EventListener<Event> {

    private weak var target: Target?

    private let block: (Target) -> (Event) -> Void

    init(_ emitter: EmitterType, _ target: Target, _ block: (Target) -> (Event) -> Void) {
        self.target = target
        self.block = block
        super.init(emitter)
    }

    override func handle(payload: Event) {
        if let target = target {
            block(target)(payload)
        }
    }
    
}
