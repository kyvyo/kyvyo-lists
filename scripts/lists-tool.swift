import CryptoKit
import Foundation
import WebKit

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

func keygen() {
    let key = Curve25519.Signing.PrivateKey()
    print("LISTS_SIGNING_KEY=\(key.rawRepresentation.base64EncodedString())")
    print("KYVYO_LISTS_PUBLIC_KEY=\(key.publicKey.rawRepresentation.base64EncodedString())")
}

func sign(_ path: String) {
    guard let encoded = ProcessInfo.processInfo.environment["LISTS_SIGNING_KEY"],
          let raw = Data(base64Encoded: encoded),
          let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: raw) else { fail("LISTS_SIGNING_KEY is missing or invalid") }
    guard let message = FileManager.default.contents(atPath: path) else { fail("Cannot read \(path)") }
    guard let signature = try? key.signature(for: message) else { fail("Signing failed") }
    let output = URL(fileURLWithPath: path).deletingPathExtension().appendingPathExtension("sig")
    do { try signature.write(to: output) } catch { fail("Cannot write \(output.path)") }
    print("signed \(path) -> \(output.lastPathComponent)")
}

@MainActor
func validate(_ paths: [String]) {
    var pending = paths.count
    var failed = false
    for path in paths {
        guard let json = try? String(contentsOfFile: path, encoding: .utf8) else { fail("Cannot read \(path)") }
        let identifier = "validate-\(UUID().uuidString)"
        WKContentRuleListStore.default().compileContentRuleList(forIdentifier: identifier, encodedContentRuleList: json) { list, error in
            if list == nil {
                failed = true
                FileHandle.standardError.write(Data("\(path): \(String(describing: error))\n".utf8))
            } else {
                print("\(path): compiled")
            }
            WKContentRuleListStore.default().removeContentRuleList(forIdentifier: identifier) { _ in }
            pending -= 1
            if pending == 0 { exit(failed ? 1 : 0) }
        }
    }
}

let arguments = Array(CommandLine.arguments.dropFirst())
switch arguments.first {
case "keygen":
    keygen()
case "sign" where arguments.count == 2:
    sign(arguments[1])
case "validate" where arguments.count > 1:
    DispatchQueue.main.async { validate(Array(arguments.dropFirst())) }
    RunLoop.main.run()
default:
    fail("usage: lists-tool.swift keygen | sign <manifest.json> | validate <blockerList.json>...")
}
