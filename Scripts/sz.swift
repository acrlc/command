#!/usr/bin/env swift-shell
import Command // ..

@main struct CountSize: Command {
 @Flag var all: Bool
 @Option var exclude: [String] = .empty // example: "[.build, .DS_Store]"
 @Inputs var inputs: [String]

 var message: String { "reading \(all ? "all " : .empty)…" }

 func inputPath(_ input: String) throws -> Path {
  if let file = try? File(path: input) { return file }
  else { return try Folder(path: input) }
 }

 func main() throws {
  let message = self.message
  var total: UInt64 = .zero

  Shell.appendInput(message)
  Shell.clearInput(message.count)

  if inputs.isEmpty {
   let folder = Folder.current
   let bytes = if all { countHidden(for: folder) } else { count(for: folder) }
   total = bytes
  } else {
   let files = try inputs.unique().map(inputPath)
   let subjects = files.filter { !$0.isSymbolicLink }.uniqued(on: \.path)

   for subject in subjects {
    if let folder = subject as? Folder {
     let bytes = if all { countHidden(for: folder) } else { count(for: folder) }
     total += bytes
    } else {
     total += subject[.size] ?? .zero
    }
   }
  }
  echo(bytes: total)
 }
}

extension CountSize {
 var formatter: ByteCountFormatter {
  let byteFormatter = ByteCountFormatter()
  byteFormatter.countStyle = .file
  byteFormatter.includesUnit = true
  byteFormatter.isAdaptive = true
  return byteFormatter
 }

 // TODO: Recurse to exclude symlinked files
 func count(for folder: Folder) -> UInt64 {
  folder.files.recursive.filter { file in
   !exclude.contains(file.name) &&
    !exclude.contains(where: { file.parent!.path.contains($0) })
  }
  .reduce(UInt64.zero) { $0 + ($1[.size] ?? .zero) }
 }

 func countHidden(for folder: Folder) -> UInt64 {
  folder.files.includingHidden.recursive.filter { file in
   !exclude.contains(file.name) &&
    !exclude.contains(where: { file.parent!.path.contains($0) })
  }
  .reduce(UInt64.zero) { $0 + ($1[.size] ?? .zero) }
 }

 func echo(bytes: UInt64) {
  print("\r" + formatter.string(fromByteCount: Int64(bytes)))
 }
}
