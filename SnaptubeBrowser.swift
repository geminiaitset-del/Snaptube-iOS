import SwiftUI
import WebKit

struct SnaptubeBrowserView: View {
    @Binding var detectedMediaURL: String
    @Binding var detectedTitle: String
    @Binding var showDownloadOptions: Bool
    
    @State private var urlString = "https://www.youtube.com"
    @State private var webView = WKWebView()
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Bar & Navigation Control
            HStack {
                Button(action: {
                    webView.goBack()
                }) {
                    Image(systemName: "chevron.left")
                        .padding()
                }
                
                TextField("ابحث أو اكتب رابط الموقع هنا...", text: $urlString, onCommit: {
                    loadURL()
                })
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.URL)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                
                Button(action: {
                    loadURL()
                }) {
                    Image(systemName: "magnifyingglass")
                        .padding()
                }
            }
            .background(Color(.systemBackground))
            
            // Web view wrapper
            WebViewWrapper(webView: webView, detectedMediaURL: $detectedMediaURL, detectedTitle: $detectedTitle, showDownloadOptions: $showDownloadOptions)
        }
    }
    
    func loadURL() {
        var cleanURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanURL.lowercased().hasPrefix("http://") && !cleanURL.lowercased().hasPrefix("https://") {
            if cleanURL.contains(".") && !cleanURL.contains(" ") {
                cleanURL = "https://" + cleanURL
            } else {
                // Search Google
                cleanURL = "https://www.google.com/search?q=" + cleanURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
            }
        }
        if let url = URL(string: cleanURL) {
            webView.load(URLRequest(url: url))
        }
    }
}

// WKWebView Coordinator & JS Injector
struct WebViewWrapper: UIViewRepresentable {
    let webView: WKWebView
    @Binding var detectedMediaURL: String
    @Binding var detectedTitle: String
    @Binding var showDownloadOptions: Bool
    
    func makeUIView(context: Context) -> WKWebView {
        webView.navigationDelegate = context.coordinator
        
        // Inject JS script to monitor document loads and capture video sources
        let config = webView.configuration
        let userContentController = config.userContentController
        
        // Media Link Detection Script (Replicating Snaptube's WebView monitor)
        let jsSource = """
        document.addEventListener('click', function(e) {
            var element = e.target.closest('a');
            if (element && element.href) {
                var url = element.href;
                if (url.includes('youtube.com/watch') || url.includes('youtu.be/') || url.includes('instagram.com/p/') || url.includes('instagram.com/reel/') || url.includes('tiktok.com/')) {
                    window.webkit.messageHandlers.snaptubeMediaHandler.postMessage({
                        url: url,
                        title: document.title
                    });
                }
            }
        }, true);
        """
        let userScript = WKUserScript(source: jsSource, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        userContentController.addUserScript(userScript)
        userContentController.add(context.coordinator, name: "snaptubeMediaHandler")
        
        // Load default URL
        if let url = URL(string: "https://m.youtube.com") {
            webView.load(URLRequest(url: url))
        }
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: WebViewWrapper
        
        init(_ parent: WebViewWrapper) {
            self.parent = parent
        }
        
        // Handle Injected JS messages
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "snaptubeMediaHandler",
               let body = message.body as? [String: Any],
               let url = body["url"] as? String,
               let title = body["title"] as? String {
                
                parent.detectedMediaURL = url
                parent.detectedTitle = title
                parent.showDownloadOptions = true
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Document loaded completely, inject secondary media checks here
        }
    }
}
