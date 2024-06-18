#!/usr/bin/env swift-shell
import Command // $main/Command
import Swizzle // @git/entangleduser/Swizzle
#if os(macOS)
import SwiftUI
protocol CommandApp: CommandProtocol & App {
 mutating func main() async throws
}

extension CommandApp {
 @_disfavoredOverload
 mutating func callAsCommand() async {
  do { try await self.main() } catch { exit(error) }
 }
 
 @_disfavoredOverload
 static func main() {
  Task.detached {
   var command = Self()
   do { try command.readArguments() } catch { exit(2, error) }
   try await command.main()
  }
  // self cannot be used for calling app
  Self.main()
 }
}

import UserNotifications
#else
#error("Current platform not supported")
#endif

@main
struct Notify: CommandApp {
 @
 @Option
 var sender: String?
 @Option
 var title: String?
 @Option
 var subtitle: String?
 @Option
 var message: String?
 /// The default input if no message is specified
 @Input
 var input: String?

 let center: UNUserNotificationCenter = .current()
 let delegate = App()
 
 var body: some Scene {
  Window(id: "") { EmptyView() }
 }
 
 
 func main() throws {
  // set sender if needed
  if let sender, sender != Bundle.sender {
   Bundle.sender = sender
  }
  // swizzle bundleID
  try Swizzle(Bundle.self) {
   #selector(getter: $0.infoDictionary)
    <-> #selector(getter: $0.newInfoDictionary)
   #selector(getter: $0.bundleURL)
    <-> #selector(getter: $0.newBundleURL)
   #selector(getter: $0.main)
    <~> #selector(getter: $0._main)
  }
  
//  center.delegate = delegate

  //print(CFBundleGetMainBundle())
//  let content = UNMutableNotificationContent()
//  if let title {
//   content.title = title
//  }
//  if let subtitle {
//   content.subtitle = subtitle
//  }
//  if let body = message ?? input {
//   content.body = body
//  }
//
//  let request = UNNotificationRequest(
//   identifier: "\(Bundle.sender)-notification", content: content,
//   trigger: nil
//  )
  // note.userInfo = options

//  if(options[@"appIcon"]){
//   [userNotification setValue:[self getImageFromURL:options[@"appIcon"]]
//   forKey:@"_identityImage"];
//   [userNotification setValue:@(false) forKey:@"_identityImageHasBorder"];
//  }
//  if(options[@"contentImage"]){
//   userNotification.contentImage = [self
//   getImageFromURL:options[@"contentImage"]];
//  }
//
//  if (sound != nil) {
//   userNotification.soundName = [sound isEqualToString: @"default"] ?
//   NSUserNotificationDefaultSoundName : sound ;
//  }
//
//  if(options[@"ignoreDnD"]){
//   [userNotification setValue:@YES forKey:@"_ignoresDoNotDisturb"];
//  }
//

  // center.delegate = self
//  [center scheduleNotification:userNotification];
  //center.add(request)
 }
}

extension Notify {
 final class Delegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
  
 }
}
@objc
extension Bundle {
 class var _main: Bundle {
  Bundle(
   url:
   NSWorkspace.shared
    .urlForApplication(withBundleIdentifier: Bundle.sender)!
  )!
 }

 static var sender: String = "com.apple.Terminal"
 var newBundleURL: URL? {
  NSWorkspace.shared.urlForApplication(withBundleIdentifier: Bundle.sender)!
 }

 var newInfoDictionary: [String: Any]? {
  [
   kIOBundleIdentifierKey: Bundle.sender,
   kIOBundleNameKey: "Notify"
  ]
 }
}
