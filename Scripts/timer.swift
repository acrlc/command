#!/usr/bin/env swift-shell
import Command // ..

@main struct Timer: Command {
 @Inputs var duration: [Duration]

 let start: Date = .now

 var nanoseconds: Int64 {
  self.duration.reduce(into: 0) { sum, next in sum += next.nanoseconds }
 }

 func main() {
  if self.nanoseconds >= 1_000_000_000 {
   let seconds = Double(nanoseconds) / 1e9
   let start = self.start
   let end = start.advanced(by: seconds)
   // MARK: - Repeat while current time is less than end time
   while true {
    guard Date.now < end else {
     // remove last buffer and exit command
     fflush(stdout)
     print("\r", terminator: .empty)
     exit(0)
    }
    // find the time since starting
    let interval = Date.now.timeIntervalSince(start)

    // create duration based on the total subtracted by the current
    let time: Duration = .seconds(seconds - interval)
    let string = time.timerView
    // print the formatted elapsed duration
    fflush(stdout)
    print("\r" + string, terminator: .empty)

    // replace the buffer with an empty string
    fflush(stdout)
    print(
     "\r" + String(repeating: .space, count: string.count),
     terminator: .empty
    )
    // repeat
    sleep(1)
   }
  } else {
   // MARK: - Error if no results or the duration is less than one second
   if self.duration.isEmpty {
    print("input <\("duration", style: .boldDim)> required")

    let arguments = CommandLine.arguments[1...].map { $0 }

    if arguments.isEmpty || arguments.first == "help" {
     print("\n" + CommandLine.usage!)
    }

    exit(-1)
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
}
