import Foundation

enum MediaError: LocalizedError {
    case compressionFailed
    case saveFailed
    case uploadFailed
    case invalidImageData
    case fileSizeExceeded
    
    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "Failed to compress image"
        case .saveFailed:
            return "Failed to save media file"
        case .uploadFailed:
            return "Failed to upload media"
        case .invalidImageData:
            return "Invalid image data"
        case .fileSizeExceeded:
            return "File size exceeds maximum allowed"
        }
    }
}
