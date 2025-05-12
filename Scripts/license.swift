#!/usr/bin/env swift-shell
import Command // ..
import SwiftTUI // @git/entangleduser/swifttui

#if canImport(CryptoKit)
import enum CryptoKit.Insecure
#else
import enum Crypto.Insecure
#endif

/// Displays any license listed on Github using the ``gh`` api command
@main struct ViewLicense: AsyncCommand {
 @Flag var list: Bool
 @Input var license: License?

 var descriptions: String {
  License.allCases.map { name, description in
   name == description ? name : "\(name), \(description)"
  }
  .joined(separator: .newline)
 }

 func main() async {
  if list {
   // FIXME: clipping when printed in a smaller window
   print(descriptions)
  } else if let license {
   print(license.body)
  } else {
   await Application(LicenseView())
  }
 }
}

struct LicenseView: View {
 @State var license: License?
 @State var errorMessage: String?

 var body: some View {
  VStack(alignment: .leading) {
   // prompt
   HStack {
    if let errorMessage {
     Text("uh oh, " + errorMessage).foregroundColor(.yellow)
     Text("try again:")
    } else {
     Text("Enter a key or command:")
    }
    TextField { input in
     let key = input.lowercased()
     if input == "exit" || input == "cancel" {
      Shell.clearLine()
      exit(0)
     }

     if input == "back" || input == "return" || input == "list" {
      license = nil
     }

     else {
      guard key.notEmpty, License.allCases.containsLowercased(key: key) else {
       errorMessage = "not an actual key,"
       return
      }
      setLicense(input)
     }
    }
    Spacer()
   }

   // license text
   if let license {
    let body = license.body
    // FIXME: doesn't scroll
    ScrollView {
     VStack(alignment: .leading) {
      // FIXME: text doesn't load
      let lines = body.split(separator: .newline).enumerated().map { ($0, $1) }
      ForEach(lines, id: \.0) {
       Text(String($1))
      }
     }
    }
   } else {
    // options
    ScrollView {
     VStack(alignment: .leading) {
      ForEach(License.allCases, id: \.0.hashValue) { name, description in
       let label = name == description ? name : "\(name), \(description)"
       Button(label) { setLicense(name) }
      }
     }
    }
   }
  }
 }

 func setLicense(_ key: String) {
  do {
   guard let license = try License(lowerecasedKey: key.lowercased()) else {
    errorMessage = "invalid input"
    return
   }
   self.license = license
   if errorMessage != nil { errorMessage = nil }
  } catch {
   errorMessage = String(error.message.prefix(while: { $0 != .newline }))
   // errorMessage = "error, please make sure you have gh cli"
  }
 }
}

/// A licence compatible with the Github CLI interface which allows direct url
/// to JSON access
/// https://docs.github.com/en/rest/licenses/licenses
struct License: JSONCodable {
 let key: String
 let name: String
 let spdx_id: String
 let url: URL // uri encoded
 let node_id: String
 let html_url: String
 let description: String
 let implementation: String
 let permissions: [String]
 let conditions: [String]
 let limitations: [String]
 let body: String
 let featured: Bool
}

extension License: LosslessStringConvertible {
 typealias AllCases = KeyValuePairs<String, String>
 static let allCases: KeyValuePairs<String, String> = [
  "AFL-3.0": "Academic Free License v3.0",
  "Apache-2.0": "Apache license 2.0",
  "Artistic-2.0": "Artistic license 2.0",
  "BSL-1.0": "Boost Software License 1.0",
  "BSD-2-Clause": "BSD 2-clause \"Simplified\" license",
  "BSD-3-Clause": "BSD 3-clause \"New\" or \"Revised\" license",
  "BSD-3-Clause-Clear": "BSD 3-clause Clear license",
  "BSD-4-Clause": "BSD 4-clause \"Original\" or \"Old\" license",
  "0BSD": "BSD Zero-Clause license",
  "CC": "Creative Commons license family",
  "CC0-1.0": "Creative Commons Zero v1.0 Universal",
  "CC-BY-4.0": "Creative Commons Attribution 4.0",
  "CC-BY-SA-4.0": "Creative Commons Attribution ShareAlike 4.0",
  "WTFPL": "Do What The F*ck You Want To Public License",
  "ECL-2.0": "Educational Community License v2.0",
  "EPL-1.0": "Eclipse Public License 1.0",
  "EPL-2.0": "Eclipse Public License 2.0",
  "EUPL-1.1": "European Union Public License 1.1",
  "AGPL-3.0": "GNU Affero General Public License v3.0",
  "GPL": "GNU General Public License family",
  "GPL-2.0": "GNU General Public License v2.0",
  "GPL-3.0": "GNU General Public License v3.0",
  "LGPL": "GNU Lesser General Public License family",
  "LGPL-2.1": "GNU Lesser General Public License v2.1",
  "LGPL-3.0": "GNU Lesser General Public License v3.0",
  "ISC": "ISC",
  "LPPL-1.3c": "LaTeX Project Public License v1.3c",
  "MS-PL": "Microsoft Public License",
  "MIT": "MIT",
  "MPL-2.0": "Mozilla Public License 2.0",
  "OSL-3.0": "Open Software License 3.0",
  "PostgreSQL": "PostgreSQL License",
  "OFL-1.1": "SIL Open Font License 1.1",
  "NCSA": "University of Illinois/NCSA Open Source License",
  "Unlicense": "The Unlicense",
  "Zlib": "zLib License"
 ]

 static func resolvedKey(from key: String) -> String? {
  let string = allCases.map(\.0).first(where: { $0.lowercased() == key })
  switch string {
  case "CC": return "CC0-1.0"
  case "GPL": return "GPL-3.0"
  case "LGPL": return "LGPL-3.0"
  default: return string
  }
 }

 init?(lowerecasedKey: String) throws {
  guard let resolvedKey = Self.resolvedKey(from: lowerecasedKey) else {
   return nil
  }
  // hash key to cache and retrieve in the temporary folder
  let hash = Insecure.MD5.hash(data: Data(resolvedKey.utf8))
   .compactMap { String(format: "%02x", $0) }
   .joined()
  let temp = Folder.temporary

  if let data = try? temp.file(named: hash).read() {
   try self.init(data)
  } else {
   let data = try processData(
    "gh",
    with: "api",
    "-H", "Accept: application/vnd.github+json",
    "-H", "X-GitHub-Api-Version: 2022-11-28",
    "/licenses/\(resolvedKey)"
   )

   // cache license
   try temp.createFile(named: hash, contents: data)
   try self.init(data)
  }
 }

 init?(_ description: String) {
  do { try self.init(lowerecasedKey: description.lowercased()) }
  catch { return nil }
 }
}

extension License.AllCases {
 func containsLowercased(key: String) -> Bool {
  map { key, _ in key.lowercased() }.contains(key)
 }
}
