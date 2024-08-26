#!/usr/bin/env swift-shell
import Command // ..
import Crypto // @git/apple/swift-crypto
import Foundation

@main
struct SuperGenPass: Command {
 @Option var secret: String?
 @Option var input: String?
 @Option var length: Int?
 @Inputs var inputs: [String]

 mutating func main() throws {
  if let secret {
   guard let input else {
    print(CommandLine.usage.unsafelyUnwrapped)
    exit(2, "input must be included")
   }

   try print(
    pwgen(secret, input, length: length ?? 10, with: Insecure.MD5.self)
     .throwing(reason: "password couldn't generate!")
   )
  } else if let input {
   let secret = String(cString: getpass("Secret: " as String))
   Shell.clearScrollback()
   
   try print(
    pwgen(secret, input, length: length ?? 10, with: Insecure.MD5.self)
     .throwing(reason: "password couldn't generate!")
   )
  } else {
   guard inputs.notEmpty else {
    print(CommandLine.usage.unsafelyUnwrapped)
    exit(2, "at least one argument must be entered (length)")
   }

   guard inputs[1].drop(while: { $0 == "-" }) != "help" else {
    print(CommandLine.usage.unsafelyUnwrapped)
    exit(0)
   }

   guard let length = Int(inputs[1]), length > 0 else {
    print(CommandLine.usage.unsafelyUnwrapped)
    exit(1, "invalid argument for length, must be an unsigned integer > 0")
   }

   var count = 1
   if inputs.count > 1 {
    guard let input = Int(inputs[2]), input > 0 else {
     exit(1, "invalid argument for count, must be an unsigned integer > 0")
    }
    count = input
   }

   let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
   for _ in 0 ..< count {
    print(
     String((0 ..< length).map { _ in chars.randomElement()! })
    )
   }
  }
 }

 init() {
  CommandLine.usage =
   """

   Prints out a random string of numbers and letters.
   \("usage", style: .bold): \
   pwgen <\("length", style: .boldDim)> <\("count", style: .boldDim)?>

   """
 }

 // MARK: SGP Implementation
 // https://github.com/mjmsmith/ubergenpass-swift/blob/main/UberGenPass/PasswordGenerator.swift
 lazy var lowerCasePattern =
  try! NSRegularExpression(pattern: "[a-z]")
 lazy var upperCasePattern =
  try! NSRegularExpression(pattern: "[A-Z]")
 lazy var digitPattern =
  try! NSRegularExpression(pattern: "[\\d]")
 lazy var domainPattern =
  try! NSRegularExpression(pattern: "[^.]+[.][^.]+")

 mutating func isValidPassword(_ password: String) -> Bool {
  let range = NSMakeRange(0, (password as NSString).length)
  return
   lowerCasePattern.rangeOfFirstMatch(in: password, range: range).location == 0
    && upperCasePattern.numberOfMatches(in: password, range: range) != 0
    && digitPattern.numberOfMatches(in: password, range: range) != 0
 }

 mutating func pwgen<A: HashFunction>(
  _ secret: String, _ input: String, length: Int, with function: A.Type
 ) -> String? {
  var password = "\(secret):\(input)"
  var count = 0

  while count < 10 || !isValidPassword(String(password.prefix(length))) {
   var byteBuffer: [UInt8] = []
   function.hash(data: password.data(using: .utf8)!).withUnsafeBytes { buffer in
    byteBuffer.append(contentsOf: buffer)
   }
   password = Data(byteBuffer).base64EncodedString()
   password = password.replacingOccurrences(of: "=", with: "A")
   password = password.replacingOccurrences(of: "+", with: "9")
   password = password.replacingOccurrences(of: "/", with: "8")
   count += 1
  }

  return String(password.prefix(length))
 }
}
