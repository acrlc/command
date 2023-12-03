@testable import Command
import XCTest

final class CommandTests: XCTestCase {
 func testCommand() throws {
  CommandLine.arguments = [#filePath, "Hello World!"]
  var command = PrintCommand()
  try command.readArguments()
  try command.main()
 }

 func testFlag() throws {
  // test flag sets to true
  CommandLine.arguments = [#filePath, "-toggle"]
  var falseCommand = AssertToggleCommand() // default is false
  try falseCommand.readArguments()
  try falseCommand.main()

  // test flag set to false
  // note: flags should be able to override
  CommandLine.arguments = [#filePath, "-t"]
  var trueCommand = AssertToggleCommand(override: true)
  try trueCommand.readArguments()
  try trueCommand.main()
 }

 func testAsyncCommand() async throws {
  CommandLine.arguments = [#filePath, "Hello World!"]
  var command = PrintAsyncCommand()
  try command.readArguments()
  try await command.main()
 }
}

extension CommandTests {
 struct PrintCommand: Command {
  @Input var input: String?

  func main() throws {
   XCTAssert(input == "Hello World!")
   print(input ?? .empty)
  }
 }

 struct AssertToggleCommand: Command {
  @Flag var toggle: Bool
  let assertion: Bool
  func main() throws {
   XCTAssert(toggle == assertion)
   print(toggle)
  }

  init() { assertion = true }
  init(override: Bool) {
   self.assertion = !override
   self._toggle.wrappedValue = override
  }
 }

 struct PrintAsyncCommand: AsyncCommand {
  @Input var input: String?

  func main() async throws {
   XCTAssert(input == "Hello World!")
   print(input ?? .empty)
  }
 }
}
