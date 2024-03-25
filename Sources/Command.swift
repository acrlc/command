@_spi(Reflection) import func ReflectionMirror._forEachFieldWithKeyPath
@_exported import Shell

public protocol CommandProtocol {}

extension CommandProperty {
 mutating func compile<Root>(
  on value: inout Root,
  property: CommandProperties<Root>.Element,
  arguments: inout [String]
  ) throws {
   do { try self.set(property.label, with: &arguments) }
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

extension CommandProtocol {
 typealias Properties = CommandProperties<Self>
 // TODO: consider the strict ordering of properties
 // properties, such as input and inputs, don't have a flag and input
 // so an ordering principle would help
 // FIXME: should consider every flag on the property at once rather than individually
 // this allows commands to be invalidated by the specific expected inputs
 mutating func readArguments() throws {
  var properties = Properties()

  _forEachFieldWithKeyPath(of: Self.self) { char, keyPath in
   let label = String(cString: char)
   if
    label.hasPrefix("_"),
    let wrapper = self[keyPath: keyPath] as? (any CommandProperty) {
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

  var arguments = CommandLine.arguments.dropFirst().map { $0 }

  func compile(for properties: Properties) throws {
   for property in properties {
    var wrapper = self[keyPath: property.keyPath] as! (any CommandProperty)
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
  // TODO: generate a usage output based on these properties
 }
}

public protocol Command: CommandProtocol {
 init()
 mutating func main() throws
 static func main()
}

public extension Command {
 @_disfavoredOverload
 func main() throws { fatalError("'\(#function)' isn't implemented") }

 @_disfavoredOverload
 mutating func callAsCommand() {
  do { try self.main() } catch { exit(error) }
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
 mutating func main() async throws
 static func main() async
}

public extension AsyncCommand {
 @_disfavoredOverload
 mutating func callAsCommand() async {
  do { try await self.main() } catch { exit(error) }
 }

 @_disfavoredOverload
 static func main() async {
  var command = Self()
  do { try command.readArguments() } catch { exit(2, error) }
  await command.callAsCommand()
 }
}
