import Foundation

public protocol EmitterType: class {
    var _listenerStorage: ListenerStorage { get }
}

public protocol EventType {
    static var eventName: String { get }
}

public protocol EventListenerType: class {
    func handle(sender: EmitterType, _ payload: EventType)
}

public class ListenerStorage {

    private static let globalEvents = ListenerStorage()
    private static var globalEventsSpinlock = OS_SPINLOCK_INIT

    private var listeners: [String: [EventListenerType]] = [:]

    public init() {
    }

    func handle(sender: EmitterType, _ payload: EventType) {
        let event = payload.dynamicType.eventName
        if let array = listeners[event] {
            for listener in array {
                listener.handle(sender, payload)
            }
        }
    }

    func add(event: String, listener: EventListenerType) {
        if var array = listeners[event] {
            array.append(listener)
            listeners[event] = array
        } else {
            listeners[event] = [listener]
        }
    }

    func remove(event: String, listener: EventListenerType) {
        if var array = listeners[event] {
            let idx = array.indexOf { $0 === listener }
            if let idx = idx {
                array.removeAtIndex(idx)
                listeners[event] = array
            }
        }
    }

}

public extension EmitterType {

    public func emit<Event: EventType>(event: Event) {
        _listenerStorage.handle(self, event)
    }

}

public extension EventType {

    public static var eventName: String {
        return String(reflecting: self)
    }

    public var eventName: String {
        return self.dynamicType.eventName
    }

    public static func addListener(listener: EventListenerType) {
        fatalError("Not implemented")
//        OSSpinLockLock(&ListenerStorage.globalEventsSpinlock)
//        OSSpinLockUnlock(&ListenerStorage.globalEventsSpinlock)
    }

    public static func removeListener(listener: EventListenerType) {
        fatalError("Not implemented")
    }

}
