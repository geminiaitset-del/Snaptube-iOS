import Foundation

class SegmentedDownloader: NSObject, URLSessionDownloadDelegate {
    
    static let shared = SegmentedDownloader()
    
    private var backgroundSession: URLSession!
    private var activeDownloads: [String: DownloadTask] = [:]
    
    override init() {
        super.init()
        let config = URLSessionConfiguration.background(withIdentifier: "com.snaptube.ios.backgroundDownload")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        self.backgroundSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }
    
    struct DownloadTask {
        let url: URL
        let fileURL: URL
        let totalSize: Int64
        var downloadedBytes: Int64
    }
    
    // Starts a segmented range request download task
    func startDownload(from urlString: String, saveTo filename: String) {
        guard let url = URL(string: urlString) else { return }
        
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let destinationURL = documentsURL.appendingPathComponent(filename)
        
        // Fetch content length and perform segmented parallel ranges
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        
        URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            guard let response = response as? HTTPURLResponse, error == nil else { return }
            let contentLength = response.expectedContentLength
            
            if contentLength > 10 * 1024 * 1024 { // Segment files larger than 10MB
                self?.downloadSegmented(url: url, destination: destinationURL, size: contentLength)
            } else {
                self?.downloadSingleThreaded(url: url, destination: destinationURL)
            }
        }.resume()
    }
    
    private func downloadSingleThreaded(url: URL, destination: URL) {
        let request = URLRequest(url: url)
        let downloadTask = backgroundSession.downloadTask(with: request)
        
        activeDownloads[downloadTask.originalRequest?.url?.absoluteString ?? ""] = DownloadTask(
            url: url,
            fileURL: destination,
            totalSize: 0,
            downloadedBytes: 0
        )
        downloadTask.resume()
    }
    
    private func downloadSegmented(url: URL, destination: URL, size: Int64) {
        let numSegments = 4
        let segmentSize = size / Int64(numSegments)
        
        for i in 0..<numSegments {
            let start = Int64(i) * segmentSize
            let end = (i == numSegments - 1) ? size - 1 : (Int64(i + 1) * segmentSize) - 1
            
            var request = URLRequest(url: url)
            request.setValue("bytes=\(start)-\(end)", forHTTPHeaderField: "Range")
            
            let downloadTask = backgroundSession.downloadTask(with: request)
            
            let partName = destination.lastPathComponent + ".part\(i)"
            let partURL = destination.deletingLastPathComponent().appendingPathComponent(partName)
            
            activeDownloads[downloadTask.originalRequest?.url?.absoluteString ?? ""] = DownloadTask(
                url: url,
                fileURL: partURL,
                totalSize: end - start + 1,
                downloadedBytes: 0
            )
            downloadTask.resume()
        }
    }
    
    // URLSessionDelegate Handlers
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let originalURLString = downloadTask.originalRequest?.url?.absoluteString,
              let task = activeDownloads[originalURLString] else { return }
        
        do {
            if FileManager.default.fileExists(atPath: task.fileURL.path) {
                try FileManager.default.removeItem(at: task.fileURL)
            }
            try FileManager.default.moveItem(at: location, to: task.fileURL)
            
            // Check if all segments are completed and merge them
            checkAndMergeParts(for: task.fileURL)
        } catch {
            print("File save error: \(error)")
        }
        
        activeDownloads.removeValue(forKey: originalURLString)
    }
    
    private func checkAndMergeParts(for partURL: URL) {
        let pathExtension = partURL.pathExtension
        guard pathExtension.contains("part") else { return }
        
        let baseFilename = partURL.deletingPathExtension().lastPathComponent
        let baseDirectory = partURL.deletingLastPathComponent()
        let finalDestination = baseDirectory.appendingPathComponent(baseFilename)
        
        // Find if all 4 parts exist
        var parts: [URL] = []
        for i in 0..<4 {
            let part = baseDirectory.appendingPathComponent(baseFilename + ".part\(i)")
            if FileManager.default.fileExists(atPath: part.path) {
                parts.append(part)
            }
        }
        
        if parts.count == 4 {
            // Merge all parts
            FileManager.default.createFile(atPath: finalDestination.path, contents: nil, attributes: nil)
            guard let fileHandle = try? FileHandle(forWritingTo: finalDestination) else { return }
            
            for part in parts {
                if let partData = try? Data(contentsOf: part) {
                    fileHandle.write(partData)
                }
                try? FileManager.default.removeItem(at: part)
            }
            fileHandle.closeFile()
            print("Successfully merged 4 segments into: \(finalDestination.lastPathComponent)")
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        // Track download percentage and notify UI
    }
}
