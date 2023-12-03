import protocol Foundation.LocalizedError

public protocol CommandError: LocalizedError, CustomStringConvertible {
 var reason: String { get }
}

public extension CommandError {
 var errorDescription: String? { reason }
}
