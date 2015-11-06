import Foundation

/**
 */


// MARK: - Event

/**
 An event that can be emitted by `EmitterType`s.

 In the simplest case, an event can be an empty struct. You can even declare it within the relevant class:

 ```
 class Foo: StdEmitterType {
     struct SomethingDidHappen: EventType {
     }

     func doSomething() {
         emit(SomethingDidHappen())
     }

     var _listeners = EventListenerStorage()
 }

 func test() {
     var o = Observation()
     var foo = Foo()
     o += foo.subscribe { (event: SomethingDidHappen, emitter) in
         print("did happen")
     }
     foo.doSomething()  // prints "did happen"
 }
 ```

 You may want to add additional details:

 ```
 struct SomethingDidHappen: EventType {
     let reason: String
 }

 class Foo: StdEmitterType {
     func doSomething() {
         emit(SomethingDidHappen("no reason at all"))
     }
     var _listeners = EventListenerStorage()
 }

 func test() {
     var o = Observation()
     var foo = Foo()
     o += foo.subscribe { (event: SomethingDidHappen, emitter) in
         print("did happen for \(event.reason)")
     }
     foo.doSomething()  // prints "did happen for no reason at all"
 }
 ```

 An event can also be a class. For example, this may be useful if you want     the event handlers to be able to return a value:

 ```
 class SomethingWillHappen: EventType {
     var allow: Bool = true
 }

 class Foo: StdEmitterType {
     func doSomething() {
     let event = SomethingWillHappen()
     emit(event)
     if event.allow {
         print("actually doing it")
     } else {
         print("forbidden")
     }
 }

 var _listeners = EventListenerStorage()
 }

 func test() {
     var o = Observation()
     var foo = Foo()
     o += foo.subscribe { (event: SomethingWillHappen, emitter) in
         event.allow = false
     }
     foo.doSomething()  // prints "forbidden"
 }
 ```
*/
public protocol EventType {
}

public extension EventType {

    /// The name of the event for debugging and logging purposes. This returns a fully qualified type name like `MyModule.Foo.SomethingDidHappen`.
    public static var eventName: String {
        return String(reflecting: self)
    }

    public var eventName: String {
        return self.dynamicType.eventName
    }

}

/**
 An event that can be posted via `NSNotificationCenter`.
*/
public protocol EventTypeWithNotification: EventType {
    /// The notification center event name. By default this returns `eventName`, which is a fully qualified type name.
    static var notificationName: String { get }
    var notificationUserInfo: [String: AnyObject] { get }
}

public extension EventTypeWithNotification {
    static var notificationName: String {
        return eventName
    }
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
    public func subscribe<Event: EventType>(block: (Event, EmitterType) -> Void) -> ListenerType {
        return BlockEventListener(self, block)
    }

    @warn_unused_result
    public func subscribe<Event: EventType, Target: AnyObject>(target: Target, _ block: (Target) -> (Event) -> Void) -> ListenerType {
        return Method1ArgEventListener(self, target, block)
    }

    @warn_unused_result
    public func subscribe<Event: EventType, Target: AnyObject>(target: Target, _ block: (Target) -> (Event, EmitterType) -> Void) -> ListenerType {
        return Method2ArgSpecificEmitterEventListener(self, target, block)
    }

    public func _emitAsNotification(event: EventType) {
        if let eventWN = event as? EventTypeWithNotification {
            NSNotificationCenter.defaultCenter().postNotificationName(eventWN.dynamicType.notificationName, object: self, userInfo: eventWN.notificationUserInfo)
        }
    }
    
}

/**
    A specific emitter implementation that contains a stored list of event listeners.

    To implement this protocol, declare a mutable `_listeners` property, initially set to `EventListenerStorage()`:

    ```
    class Foo: StdEmitterType {
        ...

        var _listeners = EventListenerStorage()
    }
    ```

    Please use StdEmitterType only for classes. For _protocols_, you should generally use EmitterType instead:

    ```
    protocol FooType: EmitterType {
        ...
    }
    class Foo: FooType, StdEmitterType {
        ...
        var _listeners = EventListenerStorage()
    }
    ```

    _An important contract detail that you don't need to understand unless you're planning to do funny things with events:_ Instances of StdEmitterType are always assumed to emit events with themselves as the type of the emitter. (As opposed to EmitterType, which may emit events with any other EmitterType.)

    */
public protocol StdEmitterType: EmitterType {

    /**
     This MUST be an instance of EventListenerStorage unique to this object;
     you are not allowed to return `someOtherObject._listeners` here.
     (Doing so would break the assumption that StdEmitterType objects always
     emit events with emitters that are instances of Self.)
    */
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

// this method is not safe to use on any EventEmitter because in case of
// event delegation, the actual emitter type might not be Self
public extension StdEmitterType {

    @warn_unused_result
    public func subscribe<Event: EventType, Target: AnyObject>(target: Target, _ block: (Target) -> (Event, Self) -> Void) -> ListenerType {
        return Method2ArgSpecificEmitterEventListener(self, target, block)
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

private final class BlockEventListener<Event: EventType>: BaseEventListener<Event> {

    private let block: (Event, EmitterType) -> Void

    init(_ emitter: EmitterType, _ block: (Event, EmitterType) -> Void) {
        self.block = block
        super.init(emitter)
    }

    override func handle(payload: EventType) {
        if let emitter = emitter {
            block(payload as! Event, emitter)
        }
    }

}

private final class Method2ArgSpecificEmitterEventListener<Event: EventType, Emitter: EmitterType, Target: AnyObject>: BaseEventListener<Event> {

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

private final class Method2ArgEventListener<Event: EventType, Target: AnyObject>: BaseEventListener<Event> {

    private weak var target: Target?

    private let block: (Target) -> (Event, EmitterType) -> Void

    init(_ emitter: EmitterType, _ target: Target, _ block: (Target) -> (Event, EmitterType) -> Void) {
        self.target = target
        self.block = block
        super.init(emitter)
    }

    override func handle(payload: EventType) {
        if let target = target, emitter = emitter {
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
