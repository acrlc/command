#!/usr/bin/env swift-shell
import Command // ../..

@main struct Greetings: Command {
 @Flag(true) var debug: Bool
 @Flag var informal: Bool
 @Inputs var people: [String]

 var prefix: String {
  informal ? "Hey" : "Hello"
 }

 func main() {
  guard !people.isEmpty else {
   return debug ? debugPrint("\(prefix)!") : print("\(prefix)!")
  }
  for person in people {
   if debug {
    debugPrint("\(prefix), \(person)!")
   } else {
    print("\(prefix), \(person)!")
   }
  }
 }
}
