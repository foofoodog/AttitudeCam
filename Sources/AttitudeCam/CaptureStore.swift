import Foundation
import UIKit
import Photos
import Combine

struct CapturedItem: Identifiable, Equatable, Sendable {
    let id: String
    let fileURL: URL
    let date: Date
    let assetLocalIdentifier: String?
}

@MainActor
final class CaptureStore: ObservableObject {
    @Published var captures: [CapturedItem] = []
    
    private let capturesDirectory: URL
    private let metadataFileURL: URL
    private var assetMap: [String: String] = [:] // filename -> PHAsset localIdentifier
    
    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        capturesDirectory = docs.appendingPathComponent("Captures", isDirectory: true)
        
        // Store internal app metadata in Application Support (hidden from user and Files app)
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        metadataFileURL = appSupport.appendingPathComponent("captures_metadata.json")
        
        // Remove or migrate any legacy JSON file from the user-visible Documents directory
        let legacyMetaURL = docs.appendingPathComponent("captures_metadata.json")
        if FileManager.default.fileExists(atPath: legacyMetaURL.path) {
            if !FileManager.default.fileExists(atPath: metadataFileURL.path) {
                try? FileManager.default.moveItem(at: legacyMetaURL, to: metadataFileURL)
            } else {
                try? FileManager.default.removeItem(at: legacyMetaURL)
            }
        }
        
        try? FileManager.default.createDirectory(at: capturesDirectory, withIntermediateDirectories: true)
        loadAssetMap()
        loadCaptures()
    }
    
    func loadCaptures() {
        guard let fileURLs = try? FileManager.default.contentsOfDirectory(
            at: capturesDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .creationDateKey],
            options: .skipsHiddenFiles
        ) else {
            return
        }
        
        let jpgFiles = fileURLs.filter { $0.pathExtension.lowercased() == "jpg" || $0.pathExtension.lowercased() == "jpeg" }
        
        let items: [CapturedItem] = jpgFiles.compactMap { url in
            let id = url.lastPathComponent
            let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
            let date = (attrs?[.creationDate] as? Date) ?? (attrs?[.modificationDate] as? Date) ?? Date()
            let localId = assetMap[id]
            return CapturedItem(id: id, fileURL: url, date: date, assetLocalIdentifier: localId)
        }
        
        // Sort newest first
        self.captures = items.sorted { $0.date > $1.date }
    }
    
    func saveCapture(jpegData: Data, assetLocalIdentifier: String?, jsonPayload: String? = nil) throws -> CapturedItem {
        let filename = String(format: "capture_%lld_%@.jpg", Int64(Date().timeIntervalSince1970 * 1000), UUID().uuidString.prefix(6) as CVarArg)
        let destinationURL = capturesDirectory.appendingPathComponent(filename)
        
        try jpegData.write(to: destinationURL, options: .atomic)
        
        // Write companion JSON sidecar file matching userguide.md specification
        if let jsonPayload = jsonPayload {
            let jsonURL = destinationURL.deletingPathExtension().appendingPathExtension("json")
            try? jsonPayload.data(using: .utf8)?.write(to: jsonURL, options: .atomic)
        }
        
        if let assetId = assetLocalIdentifier {
            assetMap[filename] = assetId
            saveAssetMap()
        }
        
        let newItem = CapturedItem(id: filename, fileURL: destinationURL, date: Date(), assetLocalIdentifier: assetLocalIdentifier)
        self.captures.insert(newItem, at: 0)
        return newItem
    }
    
    func deleteCapture(_ item: CapturedItem, completion: (@MainActor @Sendable (Bool) -> Void)? = nil) {
        let jsonURL = item.fileURL.deletingPathExtension().appendingPathExtension("json")
        if let assetId = item.assetLocalIdentifier {
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
            if assets.count > 0 {
                PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.deleteAssets(assets)
                } completionHandler: { [weak self] success, error in
                    Task { @MainActor [weak self] in
                        guard let self = self else { return }
                        if success {
                            try? FileManager.default.removeItem(at: item.fileURL)
                            try? FileManager.default.removeItem(at: jsonURL)
                            self.assetMap.removeValue(forKey: item.id)
                            self.saveAssetMap()
                            self.captures.removeAll { $0.id == item.id }
                            completion?(true)
                        } else {
                            if let error = error {
                                print("Photo delete cancelled or failed: \(error.localizedDescription)")
                            }
                            completion?(false)
                        }
                    }
                }
                return
            }
        }
        
        // If not associated with PHAsset, delete local file directly
        try? FileManager.default.removeItem(at: item.fileURL)
        try? FileManager.default.removeItem(at: jsonURL)
        self.captures.removeAll { $0.id == item.id }
        completion?(true)
    }
    
    func loadImage(for item: CapturedItem) -> UIImage? {
        UIImage(contentsOfFile: item.fileURL.path)
    }
    
    private func loadAssetMap() {
        guard let data = try? Data(contentsOf: metadataFileURL),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else {
            return
        }
        self.assetMap = dict
    }
    
    private func saveAssetMap() {
        guard let data = try? JSONEncoder().encode(assetMap) else { return }
        try? data.write(to: metadataFileURL, options: .atomic)
    }
}
