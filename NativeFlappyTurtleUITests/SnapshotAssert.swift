import UIKit
import XCTest

/// Screenshot comparison against PNG baselines in `Snapshots/Baselines/<WxH>/`
/// (WxH = screenshot pixel size, so each simulator model has its own set).
///
/// - Missing baseline: the screenshot is recorded and the test fails once.
/// - `FT_RECORD_SNAPSHOTS=1` (pass as `TEST_RUNNER_FT_RECORD_SNAPSHOTS=1` to
///   xcodebuild, or use `Scripts/test.sh --record`): re-record everything.
/// - Mismatch: actual + diff PNGs go to `Snapshots/Failures/` and the xcresult.
enum SnapshotAssert {
    /// Per-channel difference that counts a pixel as changed.
    static let pixelThreshold = 24
    /// Fraction of changed pixels tolerated (~170 px on a 1260x2736 screen).
    /// Identical renders diff at exactly 0; one small score digit is ~500 px.
    static let allowedRatio = 0.00005

    private static var snapshotsDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Snapshots")
    }

    static func assertScreen(named name: String, file: StaticString = #filePath, line: UInt = #line) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        XCTContext.runActivity(named: "Snapshot \(name)") { $0.add(attachment) }

        guard let actual = Bitmap(image: screenshot.image) else {
            return XCTFail("Could not decode screenshot", file: file, line: line)
        }
        let folder = snapshotsDir.appendingPathComponent("Baselines/\(actual.width)x\(actual.height)")
        let baselineURL = folder.appendingPathComponent("\(name).png")
        let record = ProcessInfo.processInfo.environment["FT_RECORD_SNAPSHOTS"] == "1"

        guard !record, let data = try? Data(contentsOf: baselineURL),
              let image = UIImage(data: data), let expected = Bitmap(image: image) else {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try? actual.pngData().write(to: baselineURL)
            return XCTFail("Recorded baseline \(baselineURL.path). Re-run to verify.", file: file, line: line)
        }

        guard expected.width == actual.width, expected.height == actual.height else {
            return XCTFail("Size \(actual.width)x\(actual.height) != baseline \(expected.width)x\(expected.height)",
                           file: file, line: line)
        }
        let (ratio, diff) = actual.compare(to: expected, threshold: pixelThreshold)
        guard ratio > allowedRatio else { return }

        let failures = snapshotsDir.appendingPathComponent("Failures")
        try? FileManager.default.createDirectory(at: failures, withIntermediateDirectories: true)
        try? actual.pngData().write(to: failures.appendingPathComponent("\(name)-actual.png"))
        try? diff.pngData().write(to: failures.appendingPathComponent("\(name)-diff.png"))
        let diffAttachment = XCTAttachment(data: diff.pngData(), uniformTypeIdentifier: "public.png")
        diffAttachment.name = "\(name)-diff"
        diffAttachment.lifetime = .keepAlways
        XCTContext.runActivity(named: "Snapshot diff \(name)") { $0.add(diffAttachment) }
        XCTFail(String(format: "%@ differs from baseline by %.3f%% of pixels (allowed %.3f%%). See %@",
                       name, ratio * 100, allowedRatio * 100, failures.path), file: file, line: line)
    }
}

/// RGBA8 pixel buffer.
struct Bitmap {
    let width: Int
    let height: Int
    var pixels: [UInt8]

    init?(image: UIImage) {
        guard let cgImage = image.cgImage else { return nil }
        self.init(width: cgImage.width, height: cgImage.height, pixels: [])
        pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = Bitmap.context(&pixels, width, height) else { return nil }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
    }

    init(width: Int, height: Int, pixels: [UInt8]) {
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    private static func context(_ buffer: UnsafeMutableRawPointer, _ width: Int, _ height: Int) -> CGContext? {
        CGContext(data: buffer, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    }

    func pngData() -> Data {
        var copy = pixels
        guard let image = Bitmap.context(&copy, width, height)?.makeImage() else { return Data() }
        return UIImage(cgImage: image).pngData() ?? Data()
    }

    /// Ratio of changed pixels and a diff image (changed = red, rest dimmed).
    func compare(to other: Bitmap, threshold: Int) -> (Double, Bitmap) {
        var diff = Bitmap(width: width, height: height, pixels: [UInt8](repeating: 255, count: pixels.count))
        var changed = 0
        for p in 0..<(width * height) {
            let i = p * 4
            var delta = 0
            for c in 0..<3 { delta = max(delta, abs(Int(pixels[i + c]) - Int(other.pixels[i + c]))) }
            if delta > threshold {
                changed += 1
                diff.pixels[i] = 255; diff.pixels[i + 1] = 0; diff.pixels[i + 2] = 0
            } else {
                for c in 0..<3 { diff.pixels[i + c] = other.pixels[i + c] / 4 }
            }
        }
        return (Double(changed) / Double(width * height), diff)
    }
}
