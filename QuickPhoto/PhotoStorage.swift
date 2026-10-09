import UIKit

/// Persists imported photos inside the app's own Documents folder,
/// so the photo set survives app restarts and doesn't depend on the Photos library.
final class PhotoStorage {
    private let fileManager = FileManager.default
    private let photosDirectoryURL: URL
    private let jpegCompressionQuality: CGFloat = 0.9

    init(folderName: String = "SavedPhotos") {
        let documentsDirectoryURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        photosDirectoryURL = documentsDirectoryURL.appendingPathComponent(folderName, isDirectory: true)
        try? fileManager.createDirectory(at: photosDirectoryURL, withIntermediateDirectories: true)
    }

    /// Converts any incoming image format (HEIC, PNG, etc.) to JPEG and saves it.
    @discardableResult
    func savePhoto(from originalImageData: Data) throws -> URL {
        guard
            let decodedImage = UIImage(data: originalImageData),
            let jpegData = decodedImage.jpegData(compressionQuality: jpegCompressionQuality)
        else {
            throw PhotoStorageError.unreadableImageData
        }

        let destinationFileURL = photosDirectoryURL
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")

        try jpegData.write(to: destinationFileURL, options: .atomic)
        return destinationFileURL
    }

    func allSavedPhotoURLs() -> [URL] {
        let directoryContents = try? fileManager.contentsOfDirectory(
            at: photosDirectoryURL,
            includingPropertiesForKeys: nil
        )
        return directoryContents?.filter { $0.pathExtension.lowercased() == "jpg" } ?? []
    }

    func loadImage(at photoURL: URL) -> UIImage? {
        UIImage(contentsOfFile: photoURL.path)
    }

    func deleteAllPhotos() throws {
        for savedPhotoURL in allSavedPhotoURLs() {
            try fileManager.removeItem(at: savedPhotoURL)
        }
    }
}

enum PhotoStorageError: Error {
    case unreadableImageData
}
