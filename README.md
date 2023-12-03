## Command
A library designed to convert objects into command line apps and allows properties on structs to be parsed as inputs, much like [swift-argument-parser](https://github.com/apple/swift-argument-parser) but intended to be much simpler and lightweight in order to support a wider range of expressions (and applications) that can be built using a framework of this kind.
### Potential bugs
Because this package is still early in development there could be some potential bugs such as:
- Limited control over inputs. For example, there’s isn’t a protocol for determining all acceptable styles of an input (only short or long but not both)
- The parser makes many assumptions (upside and downside). It sorts according to flag, option, then single or multiple unlabeled inputs. This may not be favored for apps that accept subcommands like `git clone` which in recursively, also accept a set of inputs
- Lack of other features that are included with other argument parsers
### `Command` and `AsyncCommand` 
Are protocols that allow `@main` to be declared on a struct so it can be used in command line apps without declaring `static main()`. This framework also makes it simple to deploy those commands quickly through type reflection.
By default, the library will read flags, options, and then unlabeled inputs
```swift
/// A command without an input
@main struct HelloWorld: Command {
 func main() {
  print("Hello, World!")
 }
}
```
### Properties
`@Input` — property reads the last input
> note: classes don’t support command properties

```swift
/// A command that prints a single input
@main struct Greeting: Command {
 @Input var person: String?

 func main() {
  print("Hello\(person == nil ? "" : ", \(person!)")!")
 }
}
```
```sh
❯ greeting $USER # "Hello, You!"
```
`@Inputs` — property supports arrays
```swift
/// A command that prints multiple inputs
@main struct Greetings: Command {
 @Inputs var people: [String] // empty
	
 func main() {
  guard !people.isEmpty else {
   return print("Hello!")
  }
  for person in people {
   print("Hello, \(person)!")
  }
 }
}
```

`@Flag` — property creates an option to toggle a value
```swift
@main struct Greetings: Command {
 // setting the wrapper to true to enable strict naming
 // instead of abbreviated and non abbreviated
 @Flag(true) var debug: Bool // false
 @Flag var informal: Bool // false
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
```
```sh
❯ greetings Swift World "John Doe" "Jane Doe" 

# flag with --debug or -debug because it's set to true or 'strict'
❯ greetings --debug Swift World "John Doe" "Jane Doe"

# set informal greetings with -i, -informal, or --informal
❯ greetings -i you # "Hey, you!"
```
`@Option` — property reads a `LosslessStringConvertible` value 
```swift
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

@main struct Run: Command {
 @Option var mode: RunMode = .start
 func main() {
  switch mode {
  case .start: print("started")
  case .pause: print("paused")
  case .stop: print("stopped …")
  }
 }
}
```
```sh
❯ run -mode start # pause or stop
```

As per usual, the library can be extended through property wrappers that conform to `CommandProperty` and read the same.

### Notes
Examples are in included in the scripts folder and can be used with [swift-shell](https://github.com/codeAcrylic/swift-shell)
It’s possible to link or alias these scripts in your command line shell if you find them useful, and if you find any improvements, fixes, or apps of your own that you would like to share, please create a pull request to update or add apps to the main branch.
All requests to either update the scripts folder or add a new feature will be taken into consideration and bug fixes are appreciated