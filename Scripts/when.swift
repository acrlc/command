#!/usr/bin/env swift-shell
import Command // ..
import Foundation
import Time // @git/acrlc/Time

@main
struct When: AsyncCommand, TimeClock, @unchecked Sendable {
 @Option
 var time: Date?
 var now: Date { time ?? .distantFuture }
 let minimumResolution: TimeInterval = 1
 var clock: ContinuousClock { .continuous }

 @Option
 var input: File?
 @Inputs
 var arguments: [String]
 mutating func main() async throws {
  guard let time, time.timeIntervalSinceNow >= 1 else {
   exit(2, "time must be a future date >= greater than one second")
  }

  var command = arguments.first

  if let input {
   if arguments.isEmpty {
    arguments = ["./{}"]
   }
   arguments =
    arguments.contains(where: { $0.contains("{}") }) ?
    arguments.map { $0.replacingOccurrences(of: "{}", with: input.path) } :
    arguments
   
   command = arguments.first
  }

  try await sleep()
  
  if let command {
   try print(processOutput(command: command, arguments[1...]))
  }
 }
}

extension Date: LosslessStringConvertible {
 public init?(_ description: String) {
  guard let description = description.wrapped else {
   return nil
  }
  var components = description.split(separator: ":")
  var offset = 0

  var digits: [Int] = .empty
  // var indicator: Substring?

  while components.notEmpty {
   let substring = components.removeFirst()
   if let digit = Int(substring) {
    digits.append(digit)
   } else if components.isEmpty {
    // indicator = substring
    break
   }
   offset += 1
  }

  guard offset > -1 else {
   return nil
  }

  let calendar = Calendar.current
  let
   hours: Int? = offset > 0 ? digits[0] : nil,
   minutes: Int? = offset > 1 ? digits[1] : nil,
   seconds: Int? = offset > 2 ? digits[2] : nil

  let start = calendar.startOfDay(for: .now)

  var interval: TimeInterval = .zero

  if let hours {
   interval += TimeInterval(hours * 3600)
  }

  if let minutes {
   interval += TimeInterval(minutes * 60)
  }

  if let seconds {
   interval += TimeInterval(seconds)
  }

  let date = start.addingTimeInterval(interval)

  guard date > .now else {
   return nil
  }
  self = date
 }
}

/*
extension Locale {
 var uses24HourTime: Bool {
  let dateFormat = DateFormatter.dateFormat(
   fromTemplate: "j",
   options: 0,
   locale: self
  )!
  return dateFormat.firstIndex(of: "a") == nil
 }
}
*/
