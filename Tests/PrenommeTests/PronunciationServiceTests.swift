import XCTest
@testable import Prenomme

final class PronunciationServiceTests: XCTestCase {

    private var service: PronunciationService { PronunciationService.shared }

    override func setUp() {
        super.setUp()
        service.stop()
    }

    func testInitialStateNotSpeaking() {
        XCTAssertFalse(service.isSpeaking)
    }

    func testSpeakSetsSpeaking() {
        service.speak("Emma", locale: "fr-FR")
        XCTAssertTrue(service.isSpeaking)
        service.stop()
    }

    func testStopClearsSpeaking() {
        service.speak("Emma", locale: "fr-FR")
        service.stop()
        XCTAssertFalse(service.isSpeaking)
    }

    func testStopWhenNotSpeakingIsNoop() {
        XCTAssertFalse(service.isSpeaking)
        service.stop()
        XCTAssertFalse(service.isSpeaking)
    }
}
