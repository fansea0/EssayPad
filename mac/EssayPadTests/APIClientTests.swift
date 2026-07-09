import XCTest
@testable import EssayPad

final class APIClientTests: XCTestCase {
    final class Mock: URLProtocol {
        static var handler: ((URLRequest) -> (HTTPURLResponse, Data))?
        override class func canInit(with: URLRequest) -> Bool { true }
        override class func canonicalRequest(for r: URLRequest) -> URLRequest { r }
        override func startLoading() {
            let (resp, data) = Mock.handler?(request) ?? (
                HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!,
                Data()
            )
            client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        }
        override func stopLoading() {}
    }

    override func setUp() {
        URLProtocol.registerClass(Mock.self)
    }
    override func tearDown() {
        URLProtocol.unregisterClass(Mock.self)
    }

    func testListNotes() async throws {
        let json = """
        {"code":0,"msg":"ok","data":{"total":1,"list":[{"id":1,"category":1,"title":"t","content":"c","created_at":1,"updated_at":1}]}}
        """.data(using: .utf8)!
        Mock.handler = { _ in
            (HTTPURLResponse(url: URL(string: "http://x")!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }
        let session = URLSession(configuration: .ephemeral, protocolClasses: [Mock.self])
        let client = APIClient(session: session)
        let (total, list) = try await client.listNotes(category: .bug)
        XCTAssertEqual(total, 1)
        XCTAssertEqual(list.first?.title, "t")
    }
}