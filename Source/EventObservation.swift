import Foundation


// MARK: - Wildcard observation


// MARK: - Instance observation

public extension Observation {

    public mutating func on <Event: EventType, Emitter: EmitterType> (eventType: Event.Type, from emitter: Emitter, block: (Emitter, Event) -> Void) {
        add(EventObserver(emitter: emitter, eventType: eventType, block: block))
    }

    public mutating func on <Event: EventType, Emitter: EmitterType> (eventType: Event.Type, from emitter: Emitter, block: () -> Void) {
        on(eventType, from: emitter) { emitter, event in block() }
    }

    public mutating func on <Event: EventType, Emitter: EmitterType, T: AnyObject> (eventType: Event.Type, from emitter: Emitter, _ observer: T, _ block: (T) -> (Emitter, Event) -> Void) {
        weak var weakObserver: T? = observer
        on(eventType, from: emitter) { emitter, event in
            if let observer = weakObserver {
                block(observer)(emitter, event)
            }
        }
    }

    public mutating func on <Event: EventType, Emitter: EmitterType, T: AnyObject> (eventType: Event.Type, from emitter: Emitter, _ observer: T, _ block: (T) -> (Event) -> Void) {
        weak var weakObserver: T? = observer
        on(eventType, from: emitter) { emitter, event in
            if let observer = weakObserver {
                block(observer)(event)
            }
        }
    }

    public mutating func on <Event: EventType, Emitter: EmitterType, T: AnyObject> (eventType: Event.Type, from emitter: Emitter, _ observer: T, _ block: (T) -> () -> Void) {
        weak var weakObserver: T? = observer
        on(eventType, from: emitter) { emitter, event in
            if let observer = weakObserver {
                block(observer)()
            }
        }
    }

}

private final class EventObserver<Emitter: EmitterType, Event: EventType>: EventListenerType, ObserverType {

    private weak var emitter: Emitter?
    private let eventType: Event.Type

    private let block: (Emitter, Event) -> Void

    init(emitter: Emitter, eventType: Event.Type, block: (Emitter, Event) -> Void) {
        self.emitter = emitter
        self.eventType = eventType
        self.block = block
        emitter._listenerStorage.add(eventType.eventName, listener: self)
    }

    deinit {
        if let emitter = emitter {
            emitter._listenerStorage.remove(eventType.eventName, listener: self)
        }
    }

    func handle(sender: EmitterType, _ payload: EventType) {
        let sender = sender as! Emitter
        let payload = payload as! Event
        block(sender, payload)
    }
    
}
