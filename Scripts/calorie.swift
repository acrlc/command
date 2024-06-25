#!/usr/bin/env swift-shell
import Command // ..
import struct Foundation.Date
import struct Foundation.TimeInterval
import class Foundation.UserDefaults
import SwiftTUI // @git/rensbreur/SwiftTUI

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
///   - reset, -r: Flag to remove all stored results.
///   - persist, -p <true/false>: Enable or disable persistent storage.
///   - count, -c <float>: Set calorie count before resuming or after resetting.
@main
struct Calorie: Command {
 @Flag
 var reset: Bool
 @Option
 var persist: Bool?
 @Option
 var count: Double?

 // MARK: - View
 struct CalorieView: View {
  final class Counter: ObservableObject {
   let hourlyCalorieBurn: Double = 2000 / 24
   // these will count our calories burned at rest
   var calorieCount: Double = storage.double(forKey: countKey) {
    didSet { storage.setValue(calorieCount, forKey: countKey) }
   }

   let hourlyCalorieTargetDeficit: Double = 500 / 24.0
   // goal is to lose 500 kcal/day (i.e. ~1 lb/week)
   var desiredDeficitCount: Double =
    storage.double(forKey: deficitKey) {
    didSet {
     storage.setValue(desiredDeficitCount, forKey: deficitKey)
    }
   }

   var lastUpdateTime: TimeInterval! =
    storage.object(forKey: updateKey) as? Double {
    didSet { storage.setValue(lastUpdateTime!, forKey: updateKey) }
   }

   func updateCalorieCount() {
    let currentTime = Date.timeIntervalSinceReferenceDate
    let elapsedHours = (currentTime - lastUpdateTime) / 3600
    calorieCount -= elapsedHours * hourlyCalorieBurn
    desiredDeficitCount -= elapsedHours * hourlyCalorieTargetDeficit
    lastUpdateTime = currentTime
    deficitColor = calorieCount < desiredDeficitCount ? Color.green : .red
   }

   func restart() {
    calorieCount = .zero
    desiredDeficitCount = .zero
    lastUpdateTime = Date.timeIntervalSinceReferenceDate
    deficitColor = SwiftTUI.Color.default
   }

   @Published
   var deficitColor = SwiftTUI.Color.default

   init() {
    if lastUpdateTime == nil {
     lastUpdateTime = Date.timeIntervalSinceReferenceDate
    } else {
     updateCalorieCount()
    }
   }
  }

  @ObservedObject
  var counter = Counter()
  var body: some View {
   VStack(alignment: .center, spacing: 1) {
    VStack(alignment: .center, spacing: 1) {
     Text("Calorie Status")

     Text(String(format: "%.2f", counter.calorieCount))

     Text("GOAL: \(String(format: "%.2f", counter.desiredDeficitCount))")
      .foregroundColor(counter.deficitColor)
    }

    HStack(spacing: 1) {
     Button(
      action: { counter.restart() },
      label: {
       Text("Reset")
      }
     )
     .background(Color.red)
     Button(
      action: {
       counter.updateCalorieCount()
       counter.calorieCount -= 100
      },
      label: {
       Text("-100 kcal")
      }
     )
     .background(Color.green)

     Button(
      action: {
       counter.updateCalorieCount()
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
   .onAppear {
    Task {
     repeat {
      try? await Task.sleep(nanoseconds: 500_000_000)
      counter.updateCalorieCount()
     } while true
    }
   }
  }
 }

 // MARK: - Main
 func main() {
  // set when not already the default or the same
  if let persist, persist != useStorage {
   print("Setting persistence to \(persist)")
   storage.setValue(persist, forKey: persistKey)
  }

  // remove persistent values
  if reset || useStorage == false {
   for key in [countKey, deficitKey, updateKey] {
    storage.removeObject(forKey: key)
   }
  }

  if let count { storage.setValue(count, forKey: countKey) }
  Application(rootView: CalorieView()).start()
 }
}
