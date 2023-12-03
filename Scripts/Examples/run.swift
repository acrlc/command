#!/usr/bin/env swift-shell
import Command // ../..

enum RunMode: String, LosslessStringConvertible {
 case start, pause, stop

 public init?(_ description: String) {
  switch description {
  case "start": self = .start
  case "pause": self = .pause
  case "stop": self = .stop
  default: return nil
  }
 }
}

/// Can take a mode as a string and confirm it, or throw error
@main struct Run: Command {
 @Input var mode: RunMode = .start
 func main() {
  switch mode {
  case .start: print("started")
  case .pause: print("paused")
  case .stop: print("stopped …")
  }
 }
}
