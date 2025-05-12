#!/usr/bin/env swift-shell
import Command // ..
import struct Foundation.Date
import struct Foundation.TimeInterval
import class Foundation.UserDefaults
import func Foundation.usleep

#if canImport(SwiftUI)
import SwiftUI
#else
import OpenCombine
#endif
import SwiftTUI // @git/entangleduser/swifttui

let storage = UserDefaults.standard
let countKey = "count"
let deficitKey = "deficit"
let updateKey = "update"
let persistKey = "persist"
var useStorage: Bool? { storage.bool(forKey: persistKey) }

/// Calorie deficit tracking command line app.
/// - note: This is a re-implementation of https://github.com/karpathy/calorie
///
/// - parameters:
///   - ui, -u: Open the desktop app instead of using the command line.
///   - reset, -r: Flag to remove all stored results.
///   - persist, -p <true/false>: Enable or disable persistent storage.
///   - count, -c <float>: Set calorie count before resuming or after resetting.
@main
struct Calorie: AsyncCommand {
 #if canImport(SwiftUI)
 @Flag
 var ui: Bool
 #endif

 @Flag
 var reset: Bool
 @Option
 var persist: Bool?
 @Option
 var count: Double?

 // MARK: - Counter -
 final class Counter: ObservableObject {
  let hourlyCalorieBurn: Double = 2000 / 24
  // these will count our calories burned at rest
  var calorieCount: Double = storage.double(forKey: countKey) {
   didSet {
    storage.set(calorieCount, forKey: countKey)
   }
  }

  let hourlyCalorieTargetDeficit: Double = 500 / 24.0
  // goal is to lose 500 kcal/day (i.e. ~1 lb/week)
  var desiredDeficitCount: Double =
   storage.double(forKey: deficitKey) {
   didSet {
    storage.set(desiredDeficitCount, forKey: deficitKey)
   }
  }

  @Published
  var lastUpdateTime: TimeInterval! =
   storage.object(forKey: updateKey) as? Double {
   didSet {
    storage.set(lastUpdateTime!, forKey: updateKey)
   }
  }

  var updateTask: Task<Void, Never>? {
   willSet { updateTask?.cancel() }
  }

  func updateCalorieCount() {
   let currentTime = Date.timeIntervalSinceReferenceDate
   let elapsedHours = (currentTime - lastUpdateTime) / 3600
   calorieCount -= elapsedHours * hourlyCalorieBurn
   desiredDeficitCount -= elapsedHours * hourlyCalorieTargetDeficit
   lastUpdateTime = currentTime
  }

  func restart() {
   calorieCount = .zero
   desiredDeficitCount = .zero
   lastUpdateTime = Date.timeIntervalSinceReferenceDate
  }

  init() {
   if lastUpdateTime == nil {
    lastUpdateTime = Date.timeIntervalSinceReferenceDate
   } else {
    updateCalorieCount()
   }
  }
 }

 // MARK: - View -
 struct CalorieView: SwiftTUI.View {
  @SwiftTUI.ObservedObject
  var counter = Calorie.Counter()
  @SwiftTUI.State
  var deficitColor = SwiftTUI.Color.default

  func updateCalorieCount() {
   counter.updateCalorieCount()
   deficitColor =
    counter.calorieCount < counter.desiredDeficitCount ? .green : .red
  }

  func startTask() {
   counter.updateTask = Task(priority: .userInitiated) {
    repeat {
     try? await sleep(nanoseconds: 500_000_000)
     updateCalorieCount()
    } while true
   }
  }

  var body: some SwiftTUI.View {
   VStack(alignment: .center, spacing: 1) {
    VStack(alignment: .center, spacing: 1) {
     Text("Calorie Status")

     Text(String(format: "%.2f", counter.calorieCount))

     Text("GOAL: \(String(format: "%.2f", counter.desiredDeficitCount))")
      .foregroundColor(deficitColor)
    }

    HStack(spacing: 1) {
     Button(
      action: {
       counter.restart()
       deficitColor = SwiftTUI.Color.default
      },
      label: {
       Text("Reset")
      }
     )
     .background(Color.red)
     Button(
      action: {
       updateCalorieCount()
       counter.calorieCount -= 100
      },
      label: {
       Text("-100 kcal")
      }
     )
     .background(Color.green)

     Button(
      action: {
       updateCalorieCount()
       counter.calorieCount += 100
      },
      label: {
       Text("+100 kcal")
      }
     )
     .background(Color.blue)
    }
    .foregroundColor(.white)
   }
   .onAppear { startTask() }
  }
 }

 #if canImport(SwiftUI)
 // MARK: - App -
 struct CalorieApp: SwiftUI.App {
  @SwiftUI.ObservedObject
  var counter = Calorie.Counter()

  @SwiftUI.State
  var deficitColor: SwiftUI.Color = .primary

  func updateCalorieCount() {
   counter.updateCalorieCount()
   deficitColor =
    counter.calorieCount < counter.desiredDeficitCount ? .green : .red
  }

  func startTask() {
   counter.updateTask = Task(priority: .userInitiated) {
    repeat {
     try? await sleep(nanoseconds: 500_000_000)
     updateCalorieCount()
    } while true
   }
  }

  func endTask() { counter.updateTask = nil }

  var body: some SwiftUI.Scene {
   WindowGroup("Calorie Status") {
    VStack(alignment: .center) {
     VStack {
      Text("Calorie Status")
       .font(.custom("Arial", size: 32))
       .fontWeight(.semibold)
       .padding(.top, 24)

      Text(String(format: "%.2f", counter.calorieCount))
       .font(.custom("Arial", size: 48))
       .padding(.vertical, 32)

      Text("GOAL: \(String(format: "%.2f", counter.desiredDeficitCount))")
       .font(.custom("Arial", size: 24))
       .foregroundStyle(deficitColor)
     }
     .padding(.bottom, 20)
     .foregroundStyle(Color.primary.opacity(0.92))

     HStack(spacing: 15) {
      Button(
       action: {
        counter.restart()
        deficitColor = .primary
       },
       label: {
        Text("Reset")
         .padding(.vertical, 10)
         .padding(.horizontal, 20)
         .contentShape(Rectangle())
       }
      )
      .background(Color.red)
      .cornerRadius(5)
      Button(
       action: {
        updateCalorieCount()
        counter.calorieCount -= 100
       },
       label: {
        Text("-100 kcal")
         .padding(.vertical, 10)
         .padding(.horizontal, 20)
         .contentShape(Rectangle())
       }
      )
      .background(Color.green)
      .cornerRadius(5)

      Button(
       action: {
        updateCalorieCount()
        counter.calorieCount += 100
       },
       label: {
        Text("+100 kcal")
         .padding(.vertical, 10)
         .padding(.horizontal, 20)
         .contentShape(Rectangle())
       }
      )
      .background(Color.blue)
      .cornerRadius(5)
     }
     .buttonStyle(.plain)
     .foregroundStyle(Color.white.opacity(0.92))
    }
    .padding(24)
    .background(.background)
    .cornerRadius(10)
    .onAppear { startTask() }
    .onDisappear { endTask() }
   }
  }
 }
 #endif

 // MARK: - Main -
 @MainActor
 func main() async {
  // set when not already the default or the same
  if let persist {
   storage.set(persist, forKey: persistKey)
  }

  // remove persistent values
  if reset || useStorage == false {
   for key in [countKey, deficitKey, updateKey] {
    storage.removeObject(forKey: key)
   }
  }

  if let count { storage.set(count, forKey: countKey) }
  #if canImport(SwiftUI)
  if ui {
   await CalorieApp.main()
  } else {
   await Application(rootView: CalorieView()).start()
  }
  #else
  await Application(rootView: CalorieView()).start()
  #endif
 }
}
