import AppKit
import WebKit

let searches = [
    "https://www.google.com/search?q=why+is+the+sky+blue&hl=en",
    "https://www.google.com/search?q=por+que+o+c%C3%A9u+%C3%A9+azul&hl=pt-BR",
    "https://www.google.com/search?q=wie+lange+ein+ei+kochen&hl=de",
]

let probe = """
(() => {
  const label = /^(AI Overview|Visão geral criada por IA|Visión general creada por IA|Übersicht mit KI)$/;
  const heading = [...document.querySelectorAll('[role=heading], div, span')].find(element => label.test((element.innerText || '').trim()));
  if (!heading) return 'absent';
  return heading.closest('#eKIzJc, div[jsname="dEwkXc"]') ? 'covered' : 'uncovered';
})()
"""

final class Checker: NSObject, WKNavigationDelegate {
    private let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 402, height: 874))
    private var pending = searches
    private var results: [(String, String)] = []

    override init() {
        super.init()
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 26_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.4 Mobile/15E148 Safari/604.1"
        webView.navigationDelegate = self
        loadNext()
    }

    private func loadNext() {
        guard let next = pending.first else { return finish() }
        webView.load(URLRequest(url: URL(string: next)!))
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            webView.evaluateJavaScript(probe) { result, _ in
                self.results.append((self.pending.removeFirst(), result as? String ?? "error"))
                self.loadNext()
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        results.append((pending.removeFirst(), "error"))
        loadNext()
    }

    private func finish() {
        for (url, result) in results { print("\(result)\t\(url)") }
        let uncovered = results.filter { $0.1 == "uncovered" }
        if !uncovered.isEmpty {
            print("::warning::Google AI Overview is no longer hidden by the annoyances rules (\(uncovered.count) of \(results.count) searches)")
        } else if !results.contains(where: { $0.1 == "covered" }) {
            print("::warning::Google AI Overview check could not confirm the rules: no AI Overview was shown")
        }
        exit(0)
    }
}

let app = NSApplication.shared
let checker = Checker()
DispatchQueue.main.asyncAfter(deadline: .now() + 120) {
    print("::warning::Google AI Overview check timed out")
    exit(0)
}
app.run()
