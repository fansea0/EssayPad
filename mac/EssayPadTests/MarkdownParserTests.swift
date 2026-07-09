import XCTest
@testable import EssayPad

final class MarkdownParserTests: XCTestCase {
    func testHeading() {
        let r = MarkdownParser.render("# 标题")
        XCTAssertTrue(r.characters.contains("标题"))
    }
    func testBold() {
        let r = MarkdownParser.render("**粗**")
        XCTAssertTrue(r.characters.contains("粗"))
    }
    func testCode() {
        let r = MarkdownParser.render("`x`")
        XCTAssertTrue(r.characters.contains("x"))
    }
    func testBullet() {
        let r = MarkdownParser.render("- 项")
        XCTAssertTrue(r.characters.contains("项"))
    }
    func testCodeBlock() {
        let r = MarkdownParser.render("```swift\nlet x = 1\n```")
        XCTAssertTrue(r.characters.contains("let x = 1"), "code body should appear")
        XCTAssertTrue(r.characters.contains("swift"), "lang label should appear")
    }
    func testCodeBlockNoLang() {
        let r = MarkdownParser.render("```\nplain\n```")
        XCTAssertTrue(r.characters.contains("plain"))
    }
    func testTaskListUnchecked() {
        let r = MarkdownParser.render("- [ ] todo")
        XCTAssertTrue(r.characters.contains("☐") || r.characters.contains("[ ]"))
    }
    func testTaskListChecked() {
        let r = MarkdownParser.render("- [x] done")
        XCTAssertTrue(r.characters.contains("☑") || r.characters.contains("[x]"))
    }
    func testHorizontalRule() {
        let r = MarkdownParser.render("---")
        XCTAssertTrue(r.characters.contains("─"))
    }
    func testStrikethrough() {
        let r = MarkdownParser.render("~~deleted~~")
        XCTAssertTrue(r.characters.contains("deleted"))
    }
    func testNestedQuote() {
        let r = MarkdownParser.render("> > > deep")
        XCTAssertTrue(r.characters.contains("deep"))
        XCTAssertTrue(r.characters.contains("│"))
    }
    func testTable() {
        let src = "| a | b |\n|---|---|\n| 1 | 2 |"
        let r = MarkdownParser.render(src)
        XCTAssertTrue(r.characters.contains("a"), "header col a")
        XCTAssertTrue(r.characters.contains("b"), "header col b")
        XCTAssertTrue(r.characters.contains("1"), "cell 1")
        XCTAssertTrue(r.characters.contains("2"), "cell 2")
        XCTAssertTrue(r.characters.contains("─"), "separator line")
    }
    func testImage() {
        let r = MarkdownParser.render("![alt text](http://x.com/y.png)")
        XCTAssertTrue(r.characters.contains("alt text"))
    }
}