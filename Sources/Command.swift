import Mirror
@_exported import Shell

public protocol CommandProtocol {}

extension CommandProtocol {
 // TODO: consider the strict ordering of properties
 // properties, such as input and inputs, don't have a flag and input
 // so an ordering principle would help
 // FIXME: should consider every flag on the property at once rather than individually
 // this allows commands to be invalidated by the specific expected inputs
 mutating func readArguments() throws {
  let typeInfo = StructMetadata(type: Self.self).toTypeInfo()
  var properties: [(info: PropertyInfo, property: any CommandProperty)] =
   typeInfo.properties.compactMap { info in
    guard let property = info.get(from: self) as? any CommandProperty
    else { return nil }
    return (info, property)
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

  func compile(for properties: [(PropertyInfo, any CommandProperty)]) throws {
   for (info, var property) in properties {
    do { try property.set(info, with: &arguments) }
    catch let error as any CommandError {
     exit(2, error.reason)
    } catch {
     throw error
    }
    info.set(value: property, on: &self)
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
 func main() throws
 static func main()
}

public extension Command {
 @_disfavoredOverload
 func main() throws { fatalError("'\(#function)' isn't implemented") }

 @_disfavoredOverload
 func callAsCommand() {
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
 func main() async throws
 static func main() async
}

public extension AsyncCommand {
 @_disfavoredOverload
 func callAsCommand() async {
  do { try await self.main() } catch { exit(error) }
 }

 @_disfavoredOverload
 static func main() async {
  var command = Self()
  do { try command.readArguments() } catch { exit(2, error) }
  await command.callAsCommand()
 }
}
