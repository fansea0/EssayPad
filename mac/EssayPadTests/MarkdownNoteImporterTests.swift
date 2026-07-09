import XCTest
@testable import EssayPad

final class MarkdownNoteImporterTests: XCTestCase {
    func testParseUsesFirstH1AsTitle() {
        let note = MarkdownNoteImporter.parse(
            markdown: "# 导入标题\n\n正文第一段\n\n## 小节\n内容",
            fallbackTitle: "file-name"
        )

        XCTAssertEqual(note.title, "导入标题")
        XCTAssertEqual(note.content, "正文第一段\n\n## 小节\n内容")
    }

    func testParseFallsBackToFilename() {
        let note = MarkdownNoteImporter.parse(
            markdown: "没有一级标题\n\n- 保留 Markdown",
            fallbackTitle: "产品想法"
        )

        XCTAssertEqual(note.title, "产品想法")
        XCTAssertEqual(note.content, "没有一级标题\n\n- 保留 Markdown")
    }
}
