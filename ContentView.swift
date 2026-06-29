import SwiftUI
import WebKit

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var detectedMediaURL: String = ""
    @State private var detectedTitle: String = ""
    @State private var showDownloadOptions = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Browser
            SnaptubeBrowserView(detectedMediaURL: $detectedMediaURL, detectedTitle: $detectedTitle, showDownloadOptions: $showDownloadOptions)
                .tabItem {
                    Image(systemName: "globe")
                    Text("المتصفح")
                }
                .tag(0)
            
            // Tab 2: Downloads
            DownloadsView()
                .tabItem {
                    Image(systemName: "arrow.down.circle")
                    Text("التحميلات")
                }
                .tag(1)
            
            // Tab 3: Media Player & Library
            LibraryView()
                .tabItem {
                    Image(systemName: "play.rectangle.on.rectangle")
                    Text("الاستوديو")
                }
                .tag(2)
        }
        .accentColor(.red)
        .sheet(isPresented: $showDownloadOptions) {
            DownloadOptionsView(mediaURL: detectedMediaURL, title: detectedTitle)
        }
    }
}

// Simple Placeholder for Downloads Tab
struct DownloadsView: View {
    var body: some View {
        NavigationView {
            List {
                Text("لا توجد تحميلات نشطة حالياً")
                    .foregroundColor(.gray)
            }
            .navigationTitle("التحميلات النشطة")
        }
    }
}

// Simple Placeholder for Library Tab
struct LibraryView: View {
    var body: some View {
        NavigationView {
            List {
                Text("مكتبة الميديا فارغة")
                    .foregroundColor(.gray)
            }
            .navigationTitle("الاستوديو المدمج")
        }
    }
}

// Sheet View for Download Options
struct DownloadOptionsView: View {
    var mediaURL: String
    var title: String
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 20) {
            Text("🎬 خيارات تحميل الميديا")
                .font(.headline)
                .padding(.top)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Divider()
            
            Button(action: {
                // Trigger audio download
                startDownload(type: "audio")
                presentationMode.wrappedValue.dismiss()
            }) {
                HStack {
                    Image(systemName: "music.note")
                    Text("تحميل مقطع صوتي (MP3)")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            
            Button(action: {
                // Trigger video download
                startDownload(type: "video")
                presentationMode.wrappedValue.dismiss()
            }) {
                HStack {
                    Image(systemName: "video")
                    Text("تحميل مقطع فيديو (MP4)")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            
            Spacer()
        }
        .padding()
    }
    
    func startDownload(type: String) {
        print("Starting \(type) download for: \(mediaURL)")
        // Call SegmentedDownloader shared instance here
    }
}
