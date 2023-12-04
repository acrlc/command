// swift-tools-version:5.5
import PackageDescription

let package = Package(
 name: "Command",
 platforms: [.macOS(.v10_15), .iOS(.v13)],
 products: [.library(name: "Command", targets: ["Command"])],
 dependencies: [
  .package(url: "https://github.com/acrlc/shell.git", branch: "main"),
  .package(url: "https://github.com/acrlc/mirror.git", from: "0.1.0")
 ],
 targets: [
  .target(
   name: "Command",
   dependencies: [
    .product(name: "Mirror", package: "mirror"),
    .product(name: "Shell", package: "shell")
   ],
   path: "Sources"
  ),
  .testTarget(name: "CommandTests", dependencies: ["Command"]),
  .testTarget(name: "CompileTests", dependencies: ["Command"])
 ]
)
