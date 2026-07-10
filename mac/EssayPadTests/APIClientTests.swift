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
        {"code":0,"msg":"ok","data":{"total":1,"list":[{"id":1,"category":1,"title":"t","content":"c","created_at":1,"updated_at":1,"task_id":0}]}}
        """.data(using: .utf8)!
        Mock.handler = { _ in
            (HTTPURLResponse(url: URL(string: "http://x")!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [Mock.self]
        let session = URLSession(configuration: config)
        let client = APIClient(session: session)
        let (total, list) = try await client.listNotes(category: NoteCategory.bug)
        XCTAssertEqual(total, 1)
        XCTAssertEqual(list.first?.title, "t")
    }

    func testListDiaries() async throws {
        let json = """
        {"code":0,"msg":"ok","data":{"total":1,"list":[{"id":7,"user_id":0,"diary_date":1783612800,"title":"今天","content":"# 记录","mood":2,"status":2,"activity":1,"created_at":1783613000,"updated_at":1783613000}]}}
        """.data(using: .utf8)!
        var requestedURL: URL?
        Mock.handler = { request in
            if request.url?.path == "/api/v1/diaries" {
                requestedURL = request.url
            }
            return (HTTPURLResponse(url: URL(string: "http://x")!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [Mock.self]
        let session = URLSession(configuration: config)
        let client = APIClient(session: session)
        let (total, list) = try await client.listDiaries(mode: DiaryListMode.week, keyword: "今天")
        XCTAssertEqual(total, 1)
        XCTAssertEqual(list.first?.id, 7)
        XCTAssertEqual(list.first?.moodName, "平静")
        let components = requestedURL.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }
        XCTAssertEqual(components?.path, "/api/v1/diaries")
        XCTAssertEqual(components?.queryItems?.first(where: { $0.name == "mode" })?.value, "week")
    }

    func testListLongTermTasksUsesLongTermGroup() async throws {
        let json = """
        {"code":0,"msg":"ok","data":{"total":0,"list":[]}}
        """.data(using: .utf8)!
        var requestedURL: URL?
        Mock.handler = { request in
            if request.url?.path == "/api/v1/tasks" {
                requestedURL = request.url
            }
            return (HTTPURLResponse(url: URL(string: "http://x")!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [Mock.self]
        let client = APIClient(session: URLSession(configuration: config))

        _ = try await client.listTasks(group: .longTerm)

        let group = requestedURL.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "group" })?.value }
        XCTAssertEqual(group, "long_term")
        XCTAssertEqual(TaskGroup.longTerm.name, "长期")
    }

    func testTaskLoadOnlyAppliesToVisibleSelectedGroup() {
        XCTAssertTrue(TaskLoadPolicy.shouldApply(
            requestedGroup: .today,
            selectedGroup: .today,
            isTasksMode: true
        ))
        XCTAssertFalse(TaskLoadPolicy.shouldApply(
            requestedGroup: .today,
            selectedGroup: .week,
            isTasksMode: true
        ))
        XCTAssertFalse(TaskLoadPolicy.shouldApply(
            requestedGroup: .today,
            selectedGroup: .today,
            isTasksMode: false
        ))
    }

    func testTodoTaskDecodesTodayPomodoroMinutes() throws {
        let json = """
        {"id":1,"title":"整理需求","description":"","progress":0,"priority":1,"status":0,"due_at":0,"created_at":1,"updated_at":1,"completed_at":0,"note_count":0,"pomodoro_count":3,"pomodoro_minutes":75,"pomodoro_today_minutes":50}
        """.data(using: .utf8)!

        let task = try JSONDecoder().decode(TodoTask.self, from: json)

        XCTAssertEqual(task.pomodoroTodayMinutes, 50)
    }
}
