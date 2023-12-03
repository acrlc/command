@testable import Command
import XCTest

final class CompileTests: XCTestCase {
 func testReadArguments() {
  measure {
   CommandLine.arguments = [#filePath, "Hello World!"]
   var command = PrintCommand()
   try! command.readArguments()
  }
 }
}

extension CompileTests {
 struct PrintCommand: Command {
  @Input var input: String?
  func main() { print(input ?? .empty) }
 }
}
