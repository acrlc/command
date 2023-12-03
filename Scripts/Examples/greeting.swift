#!/usr/bin/env swift-shell
import Command // ../..

@main struct Greeting: Command {
 @Input var person: String?

 func main() {
  print("Hello\(person == nil ? "" : ", \(person!)")!")
 }
}
