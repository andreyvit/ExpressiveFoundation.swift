import XCTest
@testable import ExpressiveFoundation

class Foo: StdEmitterType {

    var _listeners = EventListenerStorage()

    struct DidChange: EventType {
        let newValue: Int
    }

    struct DidBoo: EventTypeWithNotification {
        static let notificationName = "FooDidBoo"
        let newValue: Int
    }

    var value: Int = 1

    func change() {
        ++value
        emit(DidChange(newValue: value))
        emit(DidBoo(newValue: value))
    }

}


class ObservationTests: XCTestCase {

    var e2: XCTestExpectation!

    func testBlockListener() {
        let e1 = expectationWithDescription("Instance")

        let foo = Foo()
        var o = Observation()

        o += foo.subscribe { (event: Foo.DidChange, sender) in
            XCTAssertEqual(event.newValue, 2)
            e1.fulfill()
        }

        foo.change()

        waitForExpectationsWithTimeout(0.1, handler: nil)
    }

    func testMethodListenerWith2Args() {
        e2 = expectationWithDescription("Method")

        let foo = Foo()
        var o = Observation()

        o += foo.subscribe(self, ObservationTests.fooDidChange2)
        foo.change()

        waitForExpectationsWithTimeout(0.1, handler: nil)
    }

    func testMethodListenerWith1Arg() {
        e2 = expectationWithDescription("Method")

        let foo = Foo()
        var o = Observation()

        o += foo.subscribe(self, ObservationTests.fooDidChange1)
        foo.change()

        waitForExpectationsWithTimeout(0.1, handler: nil)
    }

    func fooDidChange2(event: Foo.DidChange, sender: Foo) {
        XCTAssertEqual(event.newValue, 2)
        e2.fulfill()
    }

    func fooDidChange1(event: Foo.DidChange) {
        XCTAssertEqual(event.newValue, 2)
        e2.fulfill()
    }

    func testNotificationBridging() {
        let foo = Foo()

        expectationForNotification(Foo.DidBoo.notificationName, object: foo, handler: nil)

        foo.change()

        waitForExpectationsWithTimeout(0.1, handler: nil)
    }

}
