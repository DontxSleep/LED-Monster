import AppKit
import CoreImage

// Keep the original logo intact; apply icon fit at packaging time.
let sourceURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
let source = CIImage(contentsOf: sourceURL, options: [.applyOrientationProperty: true])!
let canvas = source.extent
// Enlarge the previous 103% fit by another 10%.
let scale: CGFloat = 1.03 * 1.10
let featherRadius: CGFloat = 3
let fitted = source.transformed(by: CGAffineTransform(
    a: scale, b: 0, c: 0, d: scale,
    tx: canvas.midX * (1 - scale), ty: canvas.midY * (1 - scale)
)).cropped(to: canvas)

// Blur only the boundary's opacity. The eye and scales remain sharp.
let edgeMask = fitted.applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: featherRadius])
let feathered = fitted.applyingFilter("CIBlendWithAlphaMask", parameters: [
    kCIInputBackgroundImageKey: CIImage(color: .clear).cropped(to: canvas),
    kCIInputMaskImageKey: edgeMask
]).cropped(to: canvas)
let colourSpace = CGColorSpace(name: CGColorSpace.sRGB)!
let context = CIContext(options: [.workingColorSpace: colourSpace, .outputColorSpace: colourSpace])
let image = context.createCGImage(feathered, from: canvas, format: .RGBA8, colorSpace: colourSpace)!
let bitmap = NSBitmapImageRep(cgImage: image)
try bitmap.representation(using: .png, properties: [:])!.write(to: outputURL)
print("Prepared icon: 113.3% centred artwork, 3-pixel alpha feather, \(image.width)×\(image.height) canvas")
