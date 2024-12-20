#!/usr/bin/env swift-shell
import Command // ..

@main struct Timer: AsyncCommand {
 @Inputs var duration: [Duration]

 let start: Date = .now
 var seconds: TimeInterval { duration.reduce(into: .zero, +=).seconds }
 var end: Date { start.advanced(by: seconds) }
 
 func main() {
  if seconds >= 1.0 {
   // MARK: - Repeat while current time is less than end time
   while true {
    guard Date.now < end else {
     // remove last buffer and exit command
     Shell.clearLine()
     exit(0)
    }
    
    // find the time since starting
    let interval = Date.now.timeIntervalSince(start)
    // create duration based on the total subtracted by the current
    let time: Duration = .seconds((seconds - interval).rounded(.up))
    
    // replace the buffer with an empty string
    Shell.clearInput()
    // print the formatted elapsed duration
    Shell.appendInput("\(time.timerView)")

    // repeat
    // try! await sleep(for: .seconds(1))
    sleep(1)
   }
  } else {
   // MARK: - Error if no results or the duration is less than one second
   if duration.isEmpty {
    let argument = CommandLine.arguments[1...].first?.drop(while: { $0 == "-" })

    func printUsage() {
     print("\n" + CommandLine.usage!)
    }

    switch argument {
    case "help", "--help", "-help":
     printUsage()
     exit(0)
    default:
     print("input <\("duration", style: .boldDim)> required")
     printUsage()
     exit(-1)
    }
   } else {
    exit(2, "duration must be >= 1 seconds")
   }
  }
 }

 init() {
  CommandLine.usage =
   """
   usage: \("timer", color: .green) 0.5h 1m 1e3ms 1e5µs 1e9ns

   requirements:
   - numbers must be exponent notation, floating point, or whole
   - units hour, minute, second, millisecond, microsecond or nanosecond
   - sum of all measurements must be greater than one second
   """
 }
 
 func handleInput(_:Shell.InputKey) async -> Bool { false }
 func onInterruption() { 
  Shell.clearLine()
  exit(1)
 }
}
