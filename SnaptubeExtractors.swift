import Foundation

struct MediaFormat {
    let url: String
    let quality: String
    let ext: String
    let size: Int
    let type: String // "video" or "audio"
}

struct ExtractionResult {
    let title: String
    let thumbnail: String
    let duration: Int
    let formats: [MediaFormat]
    let source: String
}

class SnaptubeExtractors {
    
    // YouTube Innertube Native Swift Extractor
    static func resolveYouTube(videoID: String, completion: @escaping (ExtractionResult?) -> Void) {
        let urlString = "https://www.youtube.com/youtubei/v1/player?key=AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8"
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("com.snaptube.premium/7.56.0.75660410 (Linux; U; Android 11; en_US)", forHTTPHeaderField: "User-Agent")
        
        let payload: [String: Any] = [
            "videoId": videoID,
            "context": [
                "client": [
                    "clientName": "ANDROID",
                    "clientVersion": "17.31.35",
                    "androidSdkVersion": 30,
                    "hl": "en",
                    "gl": "US"
                ]
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
        } catch {
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let streamingData = json["streamingData"] as? [String: Any],
                   let videoDetails = json["videoDetails"] as? [String: Any] {
                    
                    let title = videoDetails["title"] as? String ?? "YouTube Video"
                    let durationStr = videoDetails["lengthSeconds"] as? String ?? "0"
                    let duration = Int(durationStr) ?? 0
                    
                    // Parse thumbnails
                    var thumbnail = ""
                    if let thumbnails = videoDetails["thumbnail"] as? [String: Any],
                       let list = thumbnails["thumbnails"] as? [[String: Any]],
                       let lastUrl = list.last?["url"] as? String {
                        thumbnail = lastUrl
                    }
                    
                    var formats: [MediaFormat] = []
                    
                    // Parse streams
                    let adaptiveFormats = streamingData["adaptiveFormats"] as? [[String: Any]] ?? []
                    let regularFormats = streamingData["formats"] as? [[String: Any]] ?? []
                    let allStreams = regularFormats + adaptiveFormats
                    
                    for stream in allStreams {
                        if let streamURL = stream["url"] as? String {
                            let mimeType = stream["mimeType"] as? String ?? ""
                            let isVideo = mimeType.contains("video")
                            let quality = stream["qualityLabel"] as? String ?? (stream["audioQuality"] as? String ?? "Unknown")
                            let sizeStr = stream["contentLength"] as? String ?? "0"
                            let size = Int(sizeStr) ?? 0
                            
                            let ext = isVideo ? "mp4" : "mp3"
                            
                            formats.append(MediaFormat(
                                url: streamURL,
                                quality: quality,
                                ext: ext,
                                size: size,
                                type: isVideo ? "video" : "audio"
                            ))
                        }
                    }
                    
                    let result = ExtractionResult(
                        title: title,
                        thumbnail: thumbnail,
                        duration: duration,
                        formats: formats,
                        source: "Innertube iOS Native"
                    )
                    completion(result)
                } else {
                    completion(nil)
                }
            } catch {
                completion(nil)
            }
        }.resume()
    }
    
    // TikTok Native Swift Extractor
    static func resolveTikTok(itemID: String, completion: @escaping (ExtractionResult?) -> Void) {
        let urlString = "https://www.tiktok.com/api/reflow/item/detail/?item_id=\(itemID)"
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let itemInfo = json["itemInfo"] as? [String: Any],
                   let itemStruct = itemInfo["itemStruct"] as? [String: Any] {
                    
                    let title = itemStruct["desc"] as? String ?? "TikTok Video"
                    let video = itemStruct["video"] as? [String: Any] ?? [:]
                    let duration = video["duration"] as? Int ?? 0
                    let thumbnail = video["cover"] as? String ?? ""
                    
                    var formats: [MediaFormat] = []
                    
                    if let playAddr = video["playAddr"] as? String {
                        formats.append(MediaFormat(url: playAddr, quality: "HD No Watermark", ext: "mp4", size: 0, type: "video"))
                    }
                    
                    if let music = itemStruct["music"] as? [String: Any],
                       let playUrl = music["playUrl"] as? String {
                        formats.append(MediaFormat(url: playUrl, quality: "Original Audio", ext: "mp3", size: 0, type: "audio"))
                    }
                    
                    let result = ExtractionResult(title: title, thumbnail: thumbnail, duration: duration, formats: formats, source: "TikTok iOS Native")
                    completion(result)
                } else {
                    completion(nil)
                }
            } catch {
                completion(nil)
            }
        }.resume()
    }
}
