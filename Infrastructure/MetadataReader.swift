import Foundation
import ImageIO
import AVFoundation
import CoreGraphics
import Darwin
import NameFixCore

public enum MetadataReader {
    public static let fields = ["created", "modified", "size", "photo.date", "photo.camera", "music.title", "music.artist", "music.album", "music.track", "video.date", "video.duration", "document.title", "document.author"]
    public static func read(_ entry: FileEntry, keys: Set<String>, format: String = "yyyy-MM-dd", zone: String = "UTC", token: CancellationToken? = nil) async throws -> [String: String] {
        guard !keys.isEmpty else { return [:] }
        if token?.cancelled == true { throw RuleFailure.cancelled }
        guard keys.isSubset(of: Set(fields)), let timezone = TimeZone(identifier: zone == "source" ? "UTC" : zone), format.count <= 100 else { throw RuleFailure.invalid }
        let fd = try FS.openDirectory(entry.path.parent); defer { close(fd) }
        guard let identity = entry.identity else { throw FSError("SourceChanged") }
        try FS.verify(fd, raw: entry.path.leaf, identity: identity)
        let stat = try FS.metadata(fd, entry.path.leaf)
        guard stat.st_flags & UInt32(SF_DATALESS) == 0 else { throw FSError("VolumeSafetyUnsupported") }
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.calendar = Calendar(identifier: .gregorian); formatter.timeZone = timezone; formatter.dateFormat = format
        var result: [String: String] = [:]
        if keys.contains("size") { result["size"] = String(stat.st_size) }
        if keys.contains("created") { result["created"] = formatter.string(from: Date(timeIntervalSince1970: Double(stat.st_birthtimespec.tv_sec))) }
        if keys.contains("modified") { result["modified"] = formatter.string(from: Date(timeIntervalSince1970: Double(stat.st_mtimespec.tv_sec))) }
        let url = URL(fileURLWithPath: entry.path.display), ext = url.pathExtension.lowercased()
        if !entry.isDirectory, keys.contains(where: { $0.hasPrefix("photo.") }), ["jpg", "jpeg", "tif", "tiff", "heic"].contains(ext) {
            guard stat.st_size < 256_000_000 else { throw RuleFailure.budget }
            if let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
               let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] {
                let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
                let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] ?? [:]
                if let camera = tiff[kCGImagePropertyTIFFModel] as? String { result["photo.camera"] = camera }
                if let date = exif[kCGImagePropertyExifDateTimeOriginal] as? String {
                    let parser = DateFormatter(); parser.locale = Locale(identifier: "en_US_POSIX"); parser.timeZone = timezone; parser.dateFormat = "yyyy:MM:dd HH:mm:ss"
                    if let offset = exif["OffsetTimeOriginal" as CFString] as? String {
                        let parts = offset.dropFirst().split(separator: ":").compactMap { Int($0) }
                        if parts.count == 2, parts[0] <= 23, parts[1] <= 59, offset.first == "+" || offset.first == "-" { parser.timeZone = TimeZone(secondsFromGMT: (parts[0] * 3600 + parts[1] * 60) * (offset.first == "-" ? -1 : 1)) }
                    }
                    if zone == "source" { formatter.timeZone = parser.timeZone }
                    if let value = parser.date(from: date) { result["photo.date"] = formatter.string(from: value) }
                }
            }
        }
        if !entry.isDirectory, keys.contains(where: { $0.hasPrefix("music.") || $0.hasPrefix("video.") }), ["mp3", "m4a", "mov", "mp4"].contains(ext) {
            guard stat.st_size < 4_000_000_000 else { throw RuleFailure.budget }
            let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: false])
            let cancellation = MediaCancellation(asset: asset)
            let timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility)), deadline = Date().addingTimeInterval(3)
            timer.schedule(deadline: .now() + .milliseconds(50), repeating: .milliseconds(50))
            timer.setEventHandler { if token?.cancelled == true || Date() > deadline { cancellation.asset.cancelLoading() } }
            timer.resume(); defer { timer.cancel() }
            let items = try await asset.load(.commonMetadata)
            for item in items {
                try Task.checkCancellation()
                guard let key = item.commonKey, let value = try await item.load(.stringValue) else { continue }
                if key == .commonKeyTitle { result["music.title"] = value }
                if key == .commonKeyArtist { result["music.artist"] = value }
                if key == .commonKeyAlbumName { result["music.album"] = value }
                if key == .commonKeyCreationDate {
                    let parser = ISO8601DateFormatter()
                    if zone == "source", value.count >= 6 {
                        let suffix = String(value.suffix(6)), parts = suffix.dropFirst().split(separator: ":").compactMap { Int($0) }
                        if parts.count == 2, parts[0] <= 23, parts[1] <= 59, suffix.first == "+" || suffix.first == "-" { formatter.timeZone = TimeZone(secondsFromGMT: (parts[0] * 3600 + parts[1] * 60) * (suffix.first == "-" ? -1 : 1)) }
                    }
                    if let date = parser.date(from: value) { result["video.date"] = formatter.string(from: date) }
                }
            }
            if keys.contains("video.duration") {
                let duration = try await asset.load(.duration).seconds
                if duration.isFinite && duration >= 0 { result["video.duration"] = String(Int(duration.rounded())) }
            }
            if keys.contains("music.track") {
                for item in try await asset.load(.metadata) {
                    if item.identifier == .id3MetadataTrackNumber || item.identifier == .iTunesMetadataTrackNumber {
                        if let value = try await item.load(.stringValue), let first = value.split(separator: "/").first { result["music.track"] = String(first) }
                        else if item.identifier == .iTunesMetadataTrackNumber, let data = try await item.load(.dataValue), data.count >= 4 { result["music.track"] = String(Int(data[2]) * 256 + Int(data[3])) }
                    }
                }
            }
        }
        if !entry.isDirectory, ext == "pdf", keys.contains(where: { $0.hasPrefix("document.") }) {
            guard stat.st_size < 64_000_000 else { throw RuleFailure.budget }
            if let document = CGPDFDocument(url as CFURL), let info = document.info {
                for (field, key) in [("document.title", "Title"), ("document.author", "Author")] {
                    var value: CGPDFStringRef?
                    if CGPDFDictionaryGetString(info, key, &value), let value, let text = CGPDFStringCopyTextString(value) { result[field] = text as String }
                }
            }
        }
        if token?.cancelled == true { throw RuleFailure.cancelled }
        try FS.verify(fd, raw: entry.path.leaf, identity: identity)
        let after = try FS.metadata(fd, entry.path.leaf)
        guard after.st_size == stat.st_size && after.st_mtimespec.tv_sec == stat.st_mtimespec.tv_sec && after.st_mtimespec.tv_nsec == stat.st_mtimespec.tv_nsec else { throw FSError("SourceChanged") }
        return result.filter { keys.contains($0.key) }
    }
}

private final class MediaCancellation: @unchecked Sendable { let asset: AVURLAsset; init(asset: AVURLAsset) { self.asset = asset } }
