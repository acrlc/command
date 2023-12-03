import Mirror

public protocol CommandProperty {
 associatedtype Value
 var wrappedValue: Value { get set }
 // Set with arguments and property info that allows reading the name of the
 // property
 mutating func set(_ info: PropertyInfo, with args: inout [String]) throws
 // Assert whether or not it's a flag, or option with no input
 var isFlag: Bool { get }
 var isOptional: Bool { get }
}

public extension CommandProperty {
 var isFlag: Bool { false }
 var isOptional: Bool { false }
}

public protocol FlaggedProperty: CommandProperty {}
public extension FlaggedProperty {
 var isFlag: Bool { true }
}

public protocol Negatable { mutating func toggle() }
extension Bool: Negatable {}

/// A property to quickly a set of flags which is usually true or false
@propertyWrapper public struct CommandFlag<Value: Negatable>: FlaggedProperty {
 /// Whether or not to use the full (strict) variable name when parsing or allow the first
 /// letter to use as an argument
 public let strict: Bool
 public var wrappedValue: Value

 public init(wrappedValue: Value, _ strict: Bool = false) {
  self.wrappedValue = wrappedValue
  self.strict = strict
 }

 public init(
  wrappedValue: Value = false, _ strict: Bool = false
 ) where Value == Bool {
  self.wrappedValue = wrappedValue
  self.strict = strict
 }

 public mutating func set(
  _ info: PropertyInfo, with args: inout [String]
 ) throws {
  var offset = 0
  while offset < args.count {
   let input = args[offset]
   if input.hasPrefix("-") {
    let argument = info.name.dropFirst()
    let option = input.drop(while: { $0 == "-" })
    if option == argument {
     self.wrappedValue.toggle()
     args.remove(at: offset)
     break
    } else if !self.strict {
     // run through single flags
     if option.count == 1, option.first == argument.first {
      self.wrappedValue.toggle()
      args.remove(at: offset)
      break
     }
    }
   }
   offset += 1
  }
 }
}

@propertyWrapper public struct CommandOption
<Input: LosslessStringConvertible>: FlaggedProperty {
 public var isOptional: Bool { true }
 public let strict: Bool
 public var wrappedValue: Input

 public init(wrappedValue: Input, _ strict: Bool = false) {
  self.wrappedValue = wrappedValue
  self.strict = strict
 }

 public init(_ strict: Bool = false) where Input: ExpressibleByNilLiteral {
  self.wrappedValue = nil
  self.strict = strict
 }

 public enum Error: CommandError {
  case conversion(str: String, arg: String)
  public var reason: String {
   switch self {
   case .conversion(let str, let arg):
    "\(arg): couldn't convert '\(str)' to object of type \(Input.self)"
   }
  }
 }

 public mutating func set(
  _ info: PropertyInfo, with args: inout [String]
 ) throws {
  var offset = 0
  while offset < args.count {
   let input = args[offset]
   if input.hasPrefix("-") {
    let argument = info.name.dropFirst()
    let option = input.drop(while: { $0 == "-" })
    let hasMatch =
     !self.strict && option.count == 1 ?
     option.first == argument.first : option == argument

    guard hasMatch else { break }
    let string = args[offset + 1]

    guard let newValue = Input(string) else {
     throw Error.conversion(str: string, arg: String(argument))
    }

    self.wrappedValue = newValue

    args.removeSubrange(offset ... offset + 1)
    break
   }
   offset += 1
  }
 }
}

@propertyWrapper public struct CommandOptions
<Input: LosslessStringConvertible>: FlaggedProperty {
 public var isOptional: Bool { true }
 public let strict: Bool
 public var wrappedValue: [Input]

 public init(wrappedValue: [Input] = .empty, _ strict: Bool = false) {
  self.wrappedValue = wrappedValue
  self.strict = strict
 }

 public enum Error: CommandError {
  case conversion(str: String, arg: String)
  public var reason: String {
   switch self {
   case .conversion(let str, let arg):
    "\(arg): couldn't convert '\(str)' to object of type \(Input.self)"
   }
  }
 }

 public mutating func set(
  _ info: PropertyInfo, with args: inout [String]
 ) throws {
  var offset = 0
  while offset < args.count {
   let input = args[offset]
   if input.hasPrefix("-") {
    let argument = info.name.dropFirst()
    let option = input.drop(while: { $0 == "-" })
    let hasMatch =
     !self.strict && option.count == 1 ?
     option.first == argument.first : option == argument

    guard hasMatch else { break }
    let lowerBound = offset + 1
    let upperBound =
     // TODO: check against array.subsequence to retain the offset
     args[lowerBound ..< args.endIndex].firstIndex(where: { $0.hasPrefix("-") })
     ?? args.endIndex

    let range = lowerBound ..< upperBound
    let inputs = args[lowerBound ..< upperBound].compactMap(Input.init)

    self.wrappedValue = inputs
    args.removeSubrange(range)
    break
   }
   offset += 1
  }
 }
}

// MARK: Inputs
@propertyWrapper
public struct CommandInput<Input: LosslessStringConvertible>: CommandProperty {
 public var wrappedValue: Input
 public init(wrappedValue: Input) {
  self.wrappedValue = wrappedValue
 }

 public enum Error: CommandError {
  case missingInput, conversion(str: String)
  public var reason: String {
   switch self {
   case .missingInput: "missing input"
   case .conversion(let str):
    "couldn't convert input '\(str)' to type \(Input.self)"
   }
  }
 }

 public mutating func set(
  _ info: PropertyInfo, with args: inout [String]
 ) throws {
  guard let last = args.last else { return }
  if let newValue = Input(last) {
   self.wrappedValue = newValue
   args.removeLast()
  } else {
   throw Error.conversion(str: args.last!)
  }
 }
}

@propertyWrapper
public struct CommandInputs<Input: LosslessStringConvertible>: CommandProperty {
 public var wrappedValue: [Input] = .empty
 public init(wrappedValue: [Input] = .empty) {
  self.wrappedValue = wrappedValue
 }

 /// Initializes a single, default input
 public init(wrappedValue: Input) {
  self.wrappedValue = [wrappedValue]
 }

 public mutating func set(
  _ info: PropertyInfo, with args: inout [String]
 ) throws {
  guard args.notEmpty else { return }
  let lowerBound = ((args.lastIndex(where: { $0.hasPrefix("-") }) ?? -1) + 1)
  let inputs = args[lowerBound ..< args.count].compactMap(Input.init)
  self.wrappedValue = inputs
  args.removeSubrange(lowerBound ..< args.count)
 }
}

public extension CommandProtocol {
 typealias Flag<Value> = CommandFlag<Value>
  where Value: Infallible & Equatable & Negatable
 typealias Option<Input> = CommandOption<Input>
  where Input: LosslessStringConvertible
 typealias Options<Input> = CommandOptions<Input>
  where Input: LosslessStringConvertible
 typealias Input<Input> = CommandInput<Input>
  where Input: LosslessStringConvertible
 typealias Inputs<Input> = CommandInputs<Input>
  where Input: LosslessStringConvertible
}

// MARK: Conformances for Optionals and RawRepresentable
extension Optional: LosslessStringConvertible
 where Wrapped: LosslessStringConvertible {
 public init?(_ description: String) {
  self = Wrapped(description)
 }
}

extension Optional: CustomStringConvertible
 where Wrapped: CustomStringConvertible {
 public var description: String { self == nil ? "nil" : self!.description }
}

public extension RawRepresentable where RawValue == String {
 init?(_ description: String) {
  self.init(rawValue: description)
 }

 var description: String { rawValue }
}

public extension RawRepresentable where RawValue: LosslessStringConvertible {
 init?(_ description: String) {
  guard let rawValue = RawValue(description) else { return nil }
  self.init(rawValue: rawValue)
 }

 var description: String { rawValue.description }
}
