// Regenerate pixel-matched PNGs from the original vector artwork.
// Run from the repository root: swift Scripts/GenerateBrandIcons.swift
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct ArtworkError: Error { let message: String }

func bitmap(width: Int, height: Int) throws -> CGContext {
    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
          let context = CGContext(data: nil, width: width, height: height,
                                  bitsPerComponent: 8, bytesPerRow: width * 4,
                                  space: colorSpace,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        throw ArtworkError(message: "Could not create the transparent bitmap")
    }
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    return context
}

// Only inspect alpha to locate excess transparent padding. Final pixels are drawn
// directly from the PDF curves, never downsampled from this measurement image.
func inkBounds(of page: CGPDFPage) throws -> CGRect {
    let box = page.getBoxRect(.mediaBox)
    let factor = 2048 / max(box.width, box.height)
    let width = Int(ceil(box.width * factor))
    let height = Int(ceil(box.height * factor))
    let context = try bitmap(width: width, height: height)
    context.scaleBy(x: factor, y: factor)
    context.translateBy(x: -box.minX, y: -box.minY)
    context.drawPDFPage(page)
    guard let bytes = context.data?.assumingMemoryBound(to: UInt8.self) else {
        throw ArtworkError(message: "Could not measure the vector artwork")
    }
    var minX = width, minY = height, maxX = -1, maxY = -1
    for y in 0..<height {
        for x in 0..<width where bytes[y * context.bytesPerRow + x * 4 + 3] > 0 {
            minX = min(minX, x); minY = min(minY, y)
            maxX = max(maxX, x); maxY = max(maxY, y)
        }
    }
    guard maxX >= minX, maxY >= minY else {
        throw ArtworkError(message: "The vector artwork is empty")
    }
    return CGRect(x: box.minX + CGFloat(minX) / factor,
                  y: box.minY + CGFloat(minY) / factor,
                  width: CGFloat(maxX - minX + 1) / factor,
                  height: CGFloat(maxY - minY + 1) / factor)
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
let sourceDirectory = root.appendingPathComponent("Design/BrandSources", isDirectory: true)
let destinationDirectory = root.appendingPathComponent("Sources/VideoDownloader/Resources", isDirectory: true)
let pointSize = CGSize(width: 36, height: 24)

for name in ["YouTubeMark", "SpotifyMark"] {
    let source = sourceDirectory.appendingPathComponent(name).appendingPathExtension("pdf")
    guard let document = CGPDFDocument(source as CFURL), let page = document.page(at: 1) else {
        throw ArtworkError(message: "Missing vector source: \(source.path)")
    }
    // YouTube supplies a precise ArtBox; Spotify's PDF retains its SVG canvas.
    let bounds = name == "YouTubeMark" ? page.getBoxRect(.artBox) : try inkBounds(of: page)
    let maximumSize = name == "YouTubeMark" ? CGSize(width: 26, height: 24) : CGSize(width: 24, height: 24)
    let fit = min(maximumSize.width / bounds.width, maximumSize.height / bounds.height)
    let offset = CGPoint(x: (pointSize.width - bounds.width * fit) / 2,
                         y: (pointSize.height - bounds.height * fit) / 2)

    for scale in 1...3 {
        let context = try bitmap(width: Int(pointSize.width) * scale,
                                 height: Int(pointSize.height) * scale)
        context.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
        context.translateBy(x: offset.x, y: offset.y)
        context.scaleBy(x: fit, y: fit)
        context.translateBy(x: -bounds.minX, y: -bounds.minY)
        context.drawPDFPage(page)
        let suffix = scale == 1 ? "" : "@\(scale)x"
        let destination = destinationDirectory.appendingPathComponent("\(name)\(suffix).png")
        guard let image = context.makeImage(),
              let writer = CGImageDestinationCreateWithURL(destination as CFURL,
                                                          UTType.png.identifier as CFString, 1, nil) else {
            throw ArtworkError(message: "Could not export \(destination.lastPathComponent)")
        }
        CGImageDestinationAddImage(writer, image, nil)
        guard CGImageDestinationFinalize(writer) else {
            throw ArtworkError(message: "Could not save \(destination.lastPathComponent)")
        }
        print("\(destination.lastPathComponent): \(image.width) × \(image.height) px")
    }
}
