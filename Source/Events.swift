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

public protocol EventTypeWithNotification: EventType {
    static var notificationName: String { get }
    var notificationUserInfo: [String: AnyObject] { get }
}

public extension EventTypeWithNotification {
    var notificationUserInfo: [String: AnyObject] {
        return [:]
    }
}


// MARK: - Emitter

public protocol EmitterType: class {

    func emit(event: EventType)

    func subscribe(listener: EventListenerType)

    func unsubscribe(listener: EventListenerType)

}

public extension EmitterType {

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

    public func _emitAsNotification(event: EventType) {
        if let eventWN = event as? EventTypeWithNotification {
            NSNotificationCenter.defaultCenter().postNotificationName(eventWN.dynamicType.notificationName, object: self, userInfo: eventWN.notificationUserInfo)
        }
    }
    
}

public protocol StdEmitterType: EmitterType {

    var _listeners: EventListenerStorage { get set }

}

public extension StdEmitterType {

    public func emit(event: EventType) {
        _emitHere(event)
    }

    public func _emitHere(event: EventType) {
        _listeners.emit(event)
        _emitAsNotification(event)
    }

    public func subscribe(listener: EventListenerType) {
        _listeners.subscribe(listener)
    }

    public func unsubscribe(listener: EventListenerType) {
        _listeners.unsubscribe(listener)
    }

}


// MARK: - Storage

public struct EventListenerStorage {

    private var subscriptionsByEventType: [ObjectIdentifier: [EventSubscription]] = [:]

    public init() {
    }

    func emit(payload: EventType) {
        let eventType = payload.dynamicType
        let oid = ObjectIdentifier(eventType)
        if let subscriptions = subscriptionsByEventType[oid] {
            for subscription in subscriptions {
                if let listener = subscription.listener {
                    if listener.eventType == eventType {
                        listener.handle(payload)
                    }
                }
            }
        }
    }

    mutating func subscribe(listener: EventListenerType) {
        let oid = ObjectIdentifier(listener.eventType)
        let subscription = EventSubscription(listener)
        if subscriptionsByEventType[oid] != nil {
            subscriptionsByEventType[oid]!.append(subscription)
        } else {
            subscriptionsByEventType[oid] = [subscription]
        }
    }

    mutating func unsubscribe(listener: EventListenerType) {
        let oid = ObjectIdentifier(listener.eventType)
        if let subscriptions = subscriptionsByEventType[oid] {
            if let idx = subscriptions.indexOf({ $0.listener === listener }) {
                subscriptionsByEventType[oid]!.removeAtIndex(idx)
            }
        }
    }

}

private struct EventSubscription {

    private weak var listener: EventListenerType?

    private init(_ listener: EventListenerType) {
        self.listener = listener
    }

}


// MARK: - Listeners

public protocol EventListenerType: ListenerType {

    var eventType: EventType.Type { get }

    func handle(payload: EventType)

}


private class BaseEventListener<Event: EventType>: EventListenerType {

    var eventType: EventType.Type {
        return Event.self
    }

    private weak var emitter: EmitterType?

    init(_ emitter: EmitterType) {
        self.emitter = emitter
        emitter.subscribe(self)
    }

    deinit {
        if let emitter = emitter {
            emitter.unsubscribe(self)
        }
    }

    func handle(payload: EventType) {
        fatalError("must override")
    }

}

private final class BlockEventListener<Event: EventType, Emitter: EmitterType>: BaseEventListener<Event> {

    private let block: (Event, Emitter) -> Void

    init(_ emitter: Emitter, _ block: (Event, Emitter) -> Void) {
        self.block = block
        super.init(emitter)
    }

    override func handle(payload: EventType) {
        // emitter might not be an instance of Emitter in case _listeners is delegated
        if let emitter = emitter as? Emitter {
            block(payload as! Event, emitter)
        }
    }

}

private final class Method2ArgEventListener<Event: EventType, Emitter: EmitterType, Target: AnyObject>: BaseEventListener<Event> {

    private weak var target: Target?

    private let block: (Target) -> (Event, Emitter) -> Void

    init(_ emitter: Emitter, _ target: Target, _ block: (Target) -> (Event, Emitter) -> Void) {
        self.target = target
        self.block = block
        super.init(emitter)
    }

    override func handle(payload: EventType) {
        // emitter might not be an instance of Emitter in case _listeners is delegated
        if let target = target, emitter = emitter as? Emitter {
            block(target)(payload as! Event, emitter)
        }
    }
    
}

private final class Method1ArgEventListener<Event: EventType, Target: AnyObject>: BaseEventListener<Event> {

    private weak var target: Target?

    private let block: (Target) -> (Event) -> Void

    init(_ emitter: EmitterType, _ target: Target, _ block: (Target) -> (Event) -> Void) {
        self.target = target
        self.block = block
        super.init(emitter)
    }

    override func handle(payload: EventType) {
        if let target = target {
            block(target)(payload as! Event)
        }
    }
    
}
