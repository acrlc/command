#!/usr/bin/env swift-shell
import Command // ..
import Foundation
import Time // @git/acrlc/Time

/// A command that relies on fixed events such as time before executing a
/// a command. This is helpful when you want to rely on absolute variables
/// which are repeatable by default.
///
/// A timer only allows you to set relative time, when (could also be called
/// wait) allows you to map to absolute states which are repeatable or can be
/// mapped to a stable event during runtime. This mostly relies on time of the
/// day or a date (which allows the process to sleep), but could also be
/// extended to other processors that work on a subscriber to transaction basis.
///
/// If you set something within when, the process will sleep until the source
/// of truth notifies our binding constant, that something has occured.
///
/// - parameter time:
/// The future time in which the next command will be activated.
@main
struct When: AsyncCommand {
 @Option
 var time: Date?
 let clock: DateClock = .minimumResolution(1)

 @Option(.strictName)
 var input: File?
 @Inputs
 var arguments: [String]

 func printUsage() {
  print("\n" + CommandLine.usage!)
 }

 consuming func main() async throws {
  guard let time, time.timeIntervalSinceNow >= 1 else {
   let argument = CommandLine.arguments[1...].first?.drop(while: { $0 == "-" })
   if argument == "help" {
    printUsage()
    exit(0)
   } else {
    echo(
     !arguments.contains(
      where: { ["t", "time"].contains($0.drop(while: { $0 == "-" })) }
     )
      ? "missing flag '-t' or '-time'"
      : "time must be a future date >= greater than one second",
     color: .yellow,
     separator: .newline
    )
    printUsage()
    exit(2)
   }
  }

  var command = arguments.isEmpty ? nil : arguments.removeFirst()

  if command != nil, let input {
   if arguments.isEmpty {
    arguments = ["./{}"]
   }
   arguments =
    arguments.contains(where: { $0.contains("{}") }) ?
    arguments.map { $0.replacingOccurrences(of: "{}", with: input.path) } :
    arguments
  }

  try await clock.sleep(until: time)

  if let command {
   try print(processOutput(command: command, arguments))
  }
 }

 init() {
  CommandLine.usage =
   """
   usage: \("when", color: .green) -time 10:30

   requirements:
   - time must be a clock measurement at least one second after the current time
   """
 }
 
 var handleInput: ((Shell.InputKey) async -> Bool)? = { _ in
  false
 }
 let onInterruption: (@convention(c) (Int32) -> Void)? = { signal in
  Shell.clearLine()
  signal == 2 ? exit(0) : exit(1)
 }
}

extension Date: LosslessStringConvertible {
 private var withPotentialFutureDate: Self {
  self > .now ? self : advanced(by: 86400)
 }

 public init?(_ description: String) {
  guard var description = description.wrapped else {
   return nil
  }
  var components =
   description
    .remove(while: { $0 != .space && !$0.isLetter })
    .split(separator: .colon)

  var offset = 0
  var digits: [Int] = .empty

  while components.notEmpty {
   let substring = components.removeFirst()
   if let digit = Int(substring) {
    digits.append(digit)
   }
   offset += 1
  }

  // note: only accepts the current day, but allows both 12 and 24 hour time
  // if locale is twelve hours, then 1 should indicate the next day if the
  // current hour is past twelve
  guard offset > 0, digits[0] <= 24 else {
   return nil
  }

  let calendar = Calendar.current
  let start = calendar.startOfDay(for: .now)

  // attempt to normalize digits that relate to signing (am/pm)
  if digits[0] < 13 {
   let trimmedDescription =
    description.trimmingCharacters(in: .whitespaces).lowercased()

   lazy var isTwelveHourTime = Locale.current.hoursPerCycle == 12

   let start = calendar.startOfDay(for: .now)

   if trimmedDescription == "am" || trimmedDescription == "pm" {
    if trimmedDescription == "pm" {
     // normalize hours if locale is based on 12 hour time
     if isTwelveHourTime {
      digits[0] += 12
     } else {
      // adjust to match the symbol if needed
      digits[0] += 12
     }
    }
   } else if isTwelveHourTime, (Date.now.timeIntervalSince(start) / 3600) !< 1 {
    // assume the time is up from zero, so 1 will equal 13 hours
    digits[0] += 12
   }
  }

  let
   hours: Int? = offset > 0 ? digits[0] : nil,
   minutes: Int? = offset > 1 ? digits[1] : nil,
   seconds: Int? = offset > 2 ? digits[2] : nil

  var interval: TimeInterval = if let seconds { Double(seconds) } else { .zero }

  if let hours {
   interval += TimeInterval(hours * 3600)
  }

  if let minutes {
   interval += TimeInterval(minutes * 60)
  }

  let date = start.addingTimeInterval(interval)
  // next day is not a question, so maybe an intializer that respects this bias
  // in the future
  self = date.withPotentialFutureDate
 }
}
