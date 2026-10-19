// Pixel diff for screenshots. Dependency-free (CoreGraphics + ImageIO).
//
//   swift Scripts/imgdiff.swift actual.png expected.png [--diff out.png]
//         [--threshold 24] [--max-ratio 0.00005] [--content]
//
// --content  crop both images to their game area (rows/columns that are mostly
//            non-black) and scale them to a common size first. Use it to compare
//            the native port against the original Cocos build, whose legacy 3:2
//            box sits at a different scale on screen.
// Exit code 0 = within --max-ratio, 1 = different, 2 = usage / IO error.
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct RGBAImage {
    let width: Int
    let height: Int
    var pixels: [UInt8]

    init(width: Int, height: Int, pixels: [UInt8]) {
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    init(cgImage: CGImage, size: CGSize? = nil, crop: CGRect? = nil) {
        let source = crop.flatMap { cgImage.cropping(to: $0) } ?? cgImage
        width = Int(size?.width ?? CGFloat(source.width))
        height = Int(size?.height ?? CGFloat(source.height))
        pixels = [UInt8](repeating: 0, count: width * height * 4)
        let context = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8,
                                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.interpolationQuality = .high
        context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
    }

    func cgImage() -> CGImage {
        var copy = pixels
        let context = CGContext(data: &copy, width: width, height: height, bitsPerComponent: 8,
                                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        return context.makeImage()!
    }

    func luma(_ x: Int, _ y: Int) -> Int {
        let i = (y * width + x) * 4
        return (Int(pixels[i]) * 3 + Int(pixels[i + 1]) * 6 + Int(pixels[i + 2])) / 10
    }

    /// Bounding box (top-left origin) of rows/columns that are mostly non-black.
    func contentRect() -> CGRect {
        func dense(_ count: Int, of total: Int) -> Bool { count * 2 > total }
        let rows = (0..<height).filter { y in dense((0..<width).filter { luma($0, y) > 10 }.count, of: width) }
        let cols = (0..<width).filter { x in dense((0..<height).filter { luma(x, $0) > 10 }.count, of: height) }
        guard let top = rows.first, let bottom = rows.last, let left = cols.first, let right = cols.last else {
            return CGRect(x: 0, y: 0, width: width, height: height)
        }
        return CGRect(x: left, y: top, width: right - left + 1, height: bottom - top + 1)
    }
}

func load(_ path: String) -> CGImage {
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        FileHandle.standardError.write("cannot read \(path)\n".data(using: .utf8)!)
        exit(2)
    }
    return image
}

func save(_ image: CGImage, to path: String) {
    let url = URL(fileURLWithPath: path) as CFURL
    guard let destination = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil) else { return }
    CGImageDestinationAddImage(destination, image, nil)
    CGImageDestinationFinalize(destination)
}

var args = Array(CommandLine.arguments.dropFirst())
func option(_ name: String) -> String? {
    guard let index = args.firstIndex(of: name), index + 1 < args.count else { return nil }
    let value = args[index + 1]
    args.removeSubrange(index...index + 1)
    return value
}
func flag(_ name: String) -> Bool {
    guard let index = args.firstIndex(of: name) else { return false }
    args.remove(at: index)
    return true
}

let diffPath = option("--diff")
let threshold = Int(option("--threshold") ?? "24")!
let maxRatio = Double(option("--max-ratio") ?? "0.00005")!
let contentMode = flag("--content")
guard args.count == 2 else {
    print("usage: imgdiff.swift actual.png expected.png [--diff out.png] [--threshold 24] [--max-ratio 0.00005] [--content]")
    exit(2)
}

let rawA = load(args[0]), rawB = load(args[1])
var a: RGBAImage
var b: RGBAImage
if contentMode {
    let fullA = RGBAImage(cgImage: rawA), fullB = RGBAImage(cgImage: rawB)
    let rectA = fullA.contentRect(), rectB = fullB.contentRect()
    // Compare at the smaller of the two game areas, keeping A's orientation.
    let size = rectA.width * rectA.height <= rectB.width * rectB.height ? rectA.size : rectB.size
    a = RGBAImage(cgImage: rawA, size: size, crop: rectA)
    b = RGBAImage(cgImage: rawB, size: size, crop: rectB)
    print("content A \(rectA) B \(rectB) -> \(Int(size.width))x\(Int(size.height))")
} else {
    a = RGBAImage(cgImage: rawA)
    b = RGBAImage(cgImage: rawB)
    guard a.width == b.width, a.height == b.height else {
        print("SIZE MISMATCH \(a.width)x\(a.height) vs \(b.width)x\(b.height)")
        exit(1)
    }
}

var differing = 0
var diff = RGBAImage(width: a.width, height: a.height, pixels: [UInt8](repeating: 0, count: a.pixels.count))
for p in 0..<(a.width * a.height) {
    let i = p * 4
    let delta = (0..<3).map { abs(Int(a.pixels[i + $0]) - Int(b.pixels[i + $0])) }.max()!
    if delta > threshold {
        differing += 1
        diff.pixels[i] = 255
        diff.pixels[i + 3] = 255
    } else {
        // Dimmed copy of the expected image for context.
        for c in 0..<3 { diff.pixels[i + c] = b.pixels[i + c] / 4 }
        diff.pixels[i + 3] = 255
    }
}
let ratio = Double(differing) / Double(a.width * a.height)
if let diffPath { save(diff.cgImage(), to: diffPath) }
print(String(format: "diff %.4f%% (%d px, threshold %d, allowed %.4f%%)", ratio * 100, differing, threshold, maxRatio * 100))
exit(ratio <= maxRatio ? 0 : 1)
