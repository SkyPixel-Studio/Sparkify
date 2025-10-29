import XCTest
@testable import Sparkify

final class TemplateEngineTests: XCTestCase {
    func testExtractPlaceholdersReturnsUniqueKeysInOrder() {
        let template = "{company} hires {role} for {company}"
        let keys = TemplateEngine.placeholders(in: template)
        XCTAssertEqual(keys, ["company", "role"], "Should keep first occurrence order and remove duplicates")
    }

    func testExtractPlaceholdersIgnoresEscapedBraces() {
        let template = "{{not_a_placeholder}} and {actual}"
        let keys = TemplateEngine.placeholders(in: template)
        XCTAssertEqual(keys, ["actual"], "Escaped braces must not be parsed as placeholders")
    }

    func testRenderSubstitutesProvidedValues() {
        let template = "Hello {name}, welcome to {company}!"
        let result = TemplateEngine.render(template: template, values: ["name": "Lem", "company": "Penguin Logistics"])
        XCTAssertEqual(result.rendered, "Hello Lem, welcome to Penguin Logistics!")
        XCTAssertTrue(result.missingKeys.isEmpty)
    }

    func testRenderPreservesMissingPlaceholders() {
        let template = "Dear {name}, your role is {role}."
        let result = TemplateEngine.render(template: template, values: ["name": "Boss"])
        XCTAssertEqual(result.rendered, "Dear Boss, your role is {role}.")
        XCTAssertEqual(result.missingKeys, ["role"])
    }

    func testRenderHandlesEscapedBraces() {
        let template = "Use {{curly}} to write a \"{{literal}}\" and {param}."
        let result = TemplateEngine.render(template: template, values: ["param": "value"])
        XCTAssertEqual(result.rendered, "Use {curly} to write a \"{literal}\" and value.")
    }

    func testRenderSkipsInvalidPlaceholderSyntax() {
        let template = "Bad {placeholder-name} stays literal"
        let result = TemplateEngine.render(template: template, values: [:])
        XCTAssertEqual(result.rendered, template)
        XCTAssertTrue(result.missingKeys.isEmpty)
    }

    func testRenderReportsMissingOncePerPlaceholder() {
        let template = "{name} meets {role} and {name} learns."
        let result = TemplateEngine.render(template: template, values: [:])
        XCTAssertEqual(result.rendered, "{name} meets {role} and {name} learns.")
        XCTAssertEqual(result.missingKeys, ["name", "role"])
    }

    func testPlaceholderDescriptorsParseEnumeration() {
        let template = "Choose {fruit:apple|banana|orange} wisely."
        let descriptors = TemplateEngine.placeholderDescriptors(in: template)
        XCTAssertEqual(descriptors.count, 1)
        let descriptor = try XCTUnwrap(descriptors.first)
        XCTAssertEqual(descriptor.key, "fruit")
        XCTAssertEqual(descriptor.options, ["apple", "banana", "orange"])
    }

    func testRenderEnumerationUsesProvidedValue() {
        let template = "I love {fruit:apple|banana}"
        let result = TemplateEngine.render(template: template, values: ["fruit": "banana"])
        XCTAssertEqual(result.rendered, "I love banana")
        XCTAssertTrue(result.missingKeys.isEmpty)
    }

    func testRewriteUpdatesEnumerationSyntax() {
        let template = "Pick {fruit} today and {fruit} tomorrow."
        let descriptor = TemplateEngine.PlaceholderDescriptor(
            key: "fruit",
            kind: .enumeration(options: ["apple", "banana"]),
            literalContent: "fruit"
        )
        let rewritten = TemplateEngine.rewrite(template: template, with: [descriptor])
        XCTAssertEqual(rewritten, "Pick {fruit:apple|banana} today and {fruit:apple|banana} tomorrow.")
    }
}
