import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

enum AppIconMaskError: LocalizedError {
    case invalidArguments
    case unreadableImage(path: String)
    case filterCreationFailed(name: String)
    case colorSpaceCreationFailed

    var errorDescription: String? {
        switch self {
        case .invalidArguments:
            "Usage: swift scripts/mask_app_icon.swift INPUT_PNG OUTPUT_PNG"
        case .unreadableImage(let path):
            "The input image could not be decoded: \(path)"
        case .filterCreationFailed(let name):
            "The required Core Image filter could not be created: \(name)"
        case .colorSpaceCreationFailed:
            "The standard RGB output color space could not be created."
        }
    }
}

func makeCircularImage(inputURL: URL) throws -> CIImage {
    guard let image = CIImage(contentsOf: inputURL, options: [.applyOrientationProperty: true]) else {
        throw AppIconMaskError.unreadableImage(path: inputURL.path)
    }

    let extent = image.extent.integral
    let center = CIVector(x: extent.midX, y: extent.midY)
    let inset = max(18.0, extent.width * 0.016)
    let radius = min(extent.width, extent.height) / 2.0 - inset

    guard let gradient = CIFilter(name: "CIRadialGradient") else {
        throw AppIconMaskError.filterCreationFailed(name: "CIRadialGradient")
    }
    gradient.setValue(center, forKey: kCIInputCenterKey)
    gradient.setValue(radius - 1.0, forKey: "inputRadius0")
    gradient.setValue(radius + 1.0, forKey: "inputRadius1")
    gradient.setValue(CIColor(red: 1, green: 1, blue: 1, alpha: 1), forKey: "inputColor0")
    gradient.setValue(CIColor(red: 0, green: 0, blue: 0, alpha: 0), forKey: "inputColor1")
    guard let mask = gradient.outputImage?.cropped(to: extent) else {
        throw AppIconMaskError.filterCreationFailed(name: "CIRadialGradient output")
    }

    guard let blend = CIFilter(name: "CIBlendWithAlphaMask") else {
        throw AppIconMaskError.filterCreationFailed(name: "CIBlendWithAlphaMask")
    }
    blend.setValue(image, forKey: kCIInputImageKey)
    blend.setValue(CIImage.empty(), forKey: kCIInputBackgroundImageKey)
    blend.setValue(mask, forKey: kCIInputMaskImageKey)
    guard let output = blend.outputImage?.cropped(to: extent) else {
        throw AppIconMaskError.filterCreationFailed(name: "CIBlendWithAlphaMask output")
    }
    return output
}

func writePNG(image: CIImage, outputURL: URL) throws {
    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
        throw AppIconMaskError.colorSpaceCreationFailed
    }
    let context = CIContext(options: [.cacheIntermediates: false])
    try context.writePNGRepresentation(
        of: image,
        to: outputURL,
        format: .RGBA8,
        colorSpace: colorSpace,
        options: [:]
    )
}

do {
    guard CommandLine.arguments.count == 3 else {
        throw AppIconMaskError.invalidArguments
    }
    let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
    let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
    let image = try makeCircularImage(inputURL: inputURL)
    try writePNG(image: image, outputURL: outputURL)
} catch {
    FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
    exit(1)
}
