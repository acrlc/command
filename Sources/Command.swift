@_spi(Reflection) import func ReflectionMirror._forEachFieldWithKeyPath
@_spi(Reflection) import struct ReflectionMirror._EachFieldOptions
import func SwiftShims.swift_isClassType
@_exported import Shell
#if canImport(SwiftTUI)
import SwiftTUI
#endif

public protocol CommandProtocol: ~Copyable {
 // FIXME: handlers have no access to the command, they would have be functions
 // which don't allow optionality on swift protocols
 var onError: ((Error) -> Void)? { get }
 #if canImport(SwiftTUI)
 @MainActor
 func onInterruption()
 func handleInput(_ key: SwiftTUI.InputKey) async -> Bool
 var inputParser: SwiftTUI.InputParser? { get }
 #else
 func onInterruption() async
 // var onInterruption: (@convention(c) (Int32) -> Void)? { get }
 func handleInput(_ key: Shell.InputKey) async -> Bool
 var inputParser: Shell.InputParser? { get }
 #endif
 var tputBellOnFalseInput: Bool { get }
}

public extension CommandProtocol {
 var onError: ((Error) -> Void)? { nil }
 #if canImport(SwiftTUI)
 @MainActor
 func onInterruption() {}
 func handleInput(_: SwiftTUI.InputKey) async -> Bool { true }
 var inputParser: SwiftTUI.InputParser? { nil }
 #else
 func onInterruption() async { exit(1) }
 // var onInterruption: (@convention(c) (Int32) -> Void)? { nil }
 func handleInput(_ key: Shell.InputKey) async -> Bool {
  Shell.write(key.rawValue)
  return true
 }
 var inputParser: Shell.InputParser? { nil }
 #endif
 var tputBellOnFalseInput: Bool { true }
}

extension CommandProperty {
 consuming func compile<Root>(
  on value: inout Root,
  property: CommandProperties<Root>.Element,
  arguments: inout [String]
 ) throws {
  do { try set(property.label, with: &arguments) }
  catch let error as any CommandError {
   exit(2, error.reason)
  } catch {
   throw error
  }
  let writableKeyPath = property.keyPath as! WritableKeyPath<Root, Self>
  value[keyPath: writableKeyPath] = self
 }
}

typealias CommandProperties<A> = [
 (label: String, keyPath: PartialKeyPath<A>, property: any CommandProperty)
]

enum CommandInfo {
 static var arguments = CommandLine.arguments
}

enum CommandParseError: LocalizedError {
 case classType(Any.Type)
 var errorDescription: String? {
  switch self {
  case let .classType(type):
   "class type: \(type) cannot be parsed"
  }
 }
}

extension CommandProtocol {
 typealias Properties = CommandProperties<Self>
 // TODO: consider the strict ordering of properties
 // properties, such as input and inputs, don't have a flag and input
 // so an ordering principle would help
 // FIXME: should consider every flag on the property at once rather than individually
 // this allows commands to be invalidated by the specific expected inputs
 mutating func readArguments() throws {
  guard
   !swift_isClassType(unsafeBitCast(Self.self, to: UnsafeRawPointer.self))
  else {
   throw CommandParseError.classType(Self.self)
  }

  var properties = Properties()

  ReflectionMirror._forEachFieldWithKeyPath(
   of: Self.self, options: _EachFieldOptions.ignoreUnknown
  ) { char, keyPath in
   let label = String(cString: char)
   if
    label.hasPrefix("_"),
    let wrapper = self[keyPath: keyPath] as? (any CommandProperty)
   {
    properties.append((label, keyPath, wrapper))
   }
   return true
  }

  guard properties.notEmpty else { return }
  // isolate flagged and optional properties from others
  let flaggedProperties = properties.drop(where: { $0.property.isFlag })
  let optionalProperties = properties.drop(where: { $0.property.isOptional })

  // TODO: throw for unknown options? but must consider inputs
  assert(
   properties.isEmpty ? true : properties.count == 1,
   "only one input property can be set per command"
  )

  var arguments = CommandInfo.arguments.dropFirst().map { $0 }

  func compile(for properties: Properties) throws {
   for property in properties {
    let wrapper = self[keyPath: property.keyPath] as! (any CommandProperty)
    try wrapper.compile(on: &self, property: property, arguments: &arguments)
   }
  }

  if flaggedProperties.notEmpty {
   try compile(for: flaggedProperties)
  }
  if optionalProperties.notEmpty {
   try compile(for: optionalProperties)
  }
  // this should either be empty, contain the input, or inputs property
  if properties.notEmpty {
   try compile(for: properties)
  }

  #if canImport(SwiftTUI)
  Application.onInterruption = onInterruption
  #else
  Task { @MainActor [self] in
   await Shell.onInterruption(self.onInterruption)
  }
  #endif

  #if canImport(SwiftTUI)
  Application.handleInput(
   bell: tputBellOnFalseInput, with: inputParser, handleInput
  )
  #else
  Shell.handleInput(bell: tputBellOnFalseInput, with: inputParser, handleInput)
  #endif
  // TODO: generate a usage output based on these properties
 }
}

public protocol Command: CommandProtocol {
 init()
 consuming func main() throws
}

public extension Command {
 @_disfavoredOverload
 func main() { fatalError("'\(#function)' isn't implemented") }

 @_disfavoredOverload
 func callAsCommand() {
  do { try main() } catch { onError?(error); exit(error) }
 }

 @_disfavoredOverload
 static func main() {
  var command = Self()
  do { try command.readArguments() } catch { exit(2, error) }
  command.callAsCommand()
 }
}

public protocol AsyncCommand: CommandProtocol {
 init()
 consuming func main() async throws
}

public extension AsyncCommand {
 @_disfavoredOverload
 consuming func callAsCommand() async {
  let copy = self
  do { try await copy.main() } catch { copy.onError?(error); exit(error) }
 }

 @_disfavoredOverload
 static func main() async {
  var command = Self()
  do { try command.readArguments() } catch { exit(2, error) }
  await command.callAsCommand()
 }
}
