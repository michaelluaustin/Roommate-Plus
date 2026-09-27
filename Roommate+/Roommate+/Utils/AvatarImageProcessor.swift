import UIKit

enum AvatarImageProcessor {
    /// Resize and compress a picked photo for upload.
    static func jpegData(from data: Data, maxDimension: CGFloat = 512, quality: CGFloat = 0.82) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        return jpegData(from: resize(image, maxDimension: maxDimension), quality: quality)
    }

    static func jpegData(from image: UIImage, quality: CGFloat = 0.82) -> Data? {
        image.jpegData(compressionQuality: quality)
    }

    private static func resize(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else { return image }

        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
