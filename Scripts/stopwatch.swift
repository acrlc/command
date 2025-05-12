#!/usr/bin/env swift-shell
import Command // ..

@main struct Stopwatch: AsyncCommand {
 // Duration to add
 @Option var add: [Duration]
 // A start time
 @Option var time: Date?
 @Option var end: Date?
 
 
 func main() {
  let start: Date = time ?? .now
  let addedSeconds = add.reduce(into: .zero, +=).seconds
  let end = start.advanced(by: addedSeconds)
  // MARK: - Repeat while current time is less than end time
  while true {
   guard Date.now > end else {
    // remove last buffer and exit command
    Shell.clearLine()
    exit(0)
   }
   
   // find the time since starting
   let interval = Date.now.timeIntervalSince(start)
   // create duration based on the start plus added time
   let time: Duration = .seconds((addedSeconds + interval).rounded(.up))
   
   // replace the buffer with an empty string
   Shell.clearInput()
   // print the formatted elapsed duration
   Shell.appendInput("\(time.timerView)")
   
   // repeat
   sleep(1)
  }
 }
 
 init() {
  // TODO: Create usage output with help option
  //  CommandLine.usage =
  //   """
  //   usage: \("timer", color: .green) 0.5h 1m 1e3ms 1e5µs 1e9ns
  //
  //   requirements:
  //   - numbers must be exponent notation, floating point, or whole
  //   - units hour, minute, second, millisecond, microsecond or nanosecond
  //   - sum of all measurements must be greater than one second
  //   """
  // }
  
  func handleInput(_: Shell.InputKey) async -> Bool { false }
  func onInterruption() {
   Shell.clearLine()
   exit(0)
  }
 }
}

extension Array: @retroactive ExpressibleByNilLiteral {
 public init(nilLiteral: ()) { self.init() }
}

 extension Date: LosslessStringConvertible {
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

   self = start.addingTimeInterval(interval)
  }
 }
