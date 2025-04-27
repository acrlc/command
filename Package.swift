// swift-tools-version:5.5
import PackageDescription

let package = Package(
 name: "Command",
 platforms: [.macOS(.v11), .iOS(.v13)],
 products: [.library(name: "Command", targets: ["Command"])],
 dependencies: [
  .package(url: "https://github.com/acrlc/shell.git", branch: "main"),
  .package(
   url: "https://github.com/acrlc/swift-reflection-mirror.git",
   branch: "wasm-compatible"
  ),
 ],
 targets: [
  .target(
   name: "Command",
   dependencies: [
    .product(name: "ReflectionMirror", package: "swift-reflection-mirror"),
    .product(name: "Shell", package: "shell")
   ],
   path: "Sources"
  ),
  .testTarget(name: "CommandTests", dependencies: ["Command"]),
  .testTarget(name: "CompileTests", dependencies: ["Command"])
 ]
)
