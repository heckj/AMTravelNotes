@testable import AMTravelNotes
import Automerge
import AutomergeSwiftAdditions
import XCTest

final class EncoderTests: XCTestCase {
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testInitialDocSetupUsingEncode() throws {
        let doc = Document()
        let enc = AutomergeEncoder(doc: doc, strategy: .createWhenNeeded)
        let model = RootModel(id: UUID(), title: "Untitled", summary: Text(""), images: [])

        try enc.encode(model)
    }
}
