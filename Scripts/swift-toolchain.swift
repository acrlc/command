#!/usr/bin/env swift-shell
import Command // ..

/// Set swift toolchains on command.
///
/// Add `source $HOME/.swift-toolchain` to your shell profile to get started or
/// indicate the source that contains your environment variable `TOOLCHAINS`
/// with the option `-s` or `--source`.
///
/// - Important: Use `-r` or `--reset` to reset to latest toolchain.
///
/// ### Limitations
/// - On setting, the version is assumed based on prefix without any additional
/// options
/// or advanced matching.
/// - Toolchains must be located under `/Library/Developer/Toolchains/` or `~/Library/Developer/Toolchains/`
/// - Latest toolchain must be in the expected locations as `swift-latest.xctoolchain` to reset
///
/// - parameters:
///  - source: The source that contains or should contain your environment variable labeled `TOOLCHAINS`
///  - reset: Resets the toolchain by removing the variable `TOOLCHAINS` from the `source` file
///  - input: The toolchain identifier or version to set
@main
struct SwiftToolchain: Command {
 @Option
 var source: File?
 @Flag
 var reset: Bool
 @Input
 var input: String?

 lazy var globalPath: Folder? =
  try? Folder(path: "/Library/Developer/Toolchains")
 lazy var userPath: Folder? =
  try? Folder.home.subfolder(at: "/Library/Developer/Toolchains")
 lazy var latestToolchain: Folder? =
  try? globalPath?.subfolder(at: "swift-latest.xctoolchain") ??
  (try? userPath?.subfolder(at: "swift-latest.xctoolchain"))

 mutating func main() throws {
  guard !reset else {
   let source =
    source ?? (try? Folder.home.createFile(named: ".swift-toolchain"))

   guard let source else {
    exit(
     1,
     """
     No valid source file set, please use the option -s <file> to specify a \
     valid source file
     """
    )
   }
   try resetIdentifier(for: source)
   return print("Toolchain was set to default")
  }
  if let input {
   if let globalPath, let id = getIdentifier(for: globalPath, with: input) {
    if let source {
     try setIdentifier(for: source, with: id)
    } else {
     setenv("TOOLCHAINS", id, 1)
    }
    print("Toolchain was set to '\(id)'")

   } else if let userPath, let id = getIdentifier(for: userPath, with: input) {
    if let source {
     try setIdentifier(for: source, with: id)
    } else {
     setenv("TOOLCHAINS", id, 1)
    }
    print("Toolchain was set to '\(id)'")

   } else {
    exit(1, "No swift toolchain was installed for '\(input)'")
   }
  } else {
   if let id = Shell.env["TOOLCHAINS"] {
    if
     let globalPath,
     let version = getVersionWithIdentifier(for: globalPath, with: id) {
     print(
      "\("Current:", style: .underlined)",
      "\(version, style: [.bold, .italic])"
     )
    }
    else if
     let userPath,
     let version = getVersionWithIdentifier(for: userPath, with: id) {
     print(
      "\("Current:", style: .underlined)",
      "\(version, style: [.bold, .italic])"
     )
    }
   } else if
    let latestToolchain,
    let version = getVersion(for: latestToolchain) {
    print("\("Latest:", style: .underlined)", "\(version, style: .bold)")
   } else if let swiftVersion = try? processOutput(.swift, with: "--version") {
    print(swiftVersion)
   }
  }
 }

 // MARK: Functions
 func getVersion(for folder: Folder) -> String? {
  guard let bundle = Bundle(url: folder.url) else {
   return nil
  }
  return bundle.infoDictionary?["Version"] as? String
 }

 func getIdentifier(for folder: Folder) -> String? {
  guard let bundle = Bundle(url: folder.url) else {
   return nil
  }
  return bundle.infoDictionary?["CFBundleIdentifier"] as? String
 }

 func getIdentifier(for folder: Folder, with string: String) -> String? {
  for path in folder.subfolders where path.extension == "xctoolchain" {
   if let id = getIdentifier(for: path) {
    if id == string {
     return id
    } else
    if
     let version =
     getVersion(for: path), version.split(separator: ".")
      .dropLast().joined(separator: ".") == string {
     return id
    }
   }
  }
  return nil
 }

 func getVersionWithIdentifier(
  for folder: Folder,
  with string: String
 ) -> String? {
  for path in folder.subfolders where path.extension == "xctoolchain" {
   guard
    let id = getIdentifier(for: path), id == string,
    let version = getVersion(for: path) else {
    continue
   }
   return version
  }
  return nil
 }

 func setIdentifier(for source: File, with id: String) throws {
  let string = try source.readAsString()
  var split = string.split(separator: .newline)
  lazy var variable: Substring = "export TOOLCHAINS=\(id)"
  if
   let variableIndex =
   split.firstIndex(where: { $0.hasPrefix("export TOOLCHAINS") }) {
   split[variableIndex] = variable
   split[variableIndex...]
    .removeAll(where: { $0.contains("export TOOLCHAINS") })
  } else {
   split.append(variable)
  }
  let out = split.joined(separator: .newline)
  try out.data(using: .utf8).unsafelyUnwrapped.write(to: source.url)
 }

 func resetIdentifier(for source: File) throws {
  let string = try source.readAsString()
  var split = string.split(separator: .newline)
  if
   let variableIndex =
   split.firstIndex(where: { $0.hasPrefix("export TOOLCHAINS") }) {
   split.remove(at: variableIndex)
   split[variableIndex...]
    .removeAll(where: { $0.contains("export TOOLCHAINS") })
  }

  let out = split.joined(separator: .newline)
  try out.data(using: .utf8).unsafelyUnwrapped.write(to: source.url)
 }
}
