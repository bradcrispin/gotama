import Foundation
import AppKit

// Configuration
let useInvertedColors = true // Set to true for accent color background with white asterisk

// Create canvas size and calculate symbol size (82% of canvas)
let canvasSize = CGSize(width: 1024, height: 1024)
let symbolSize = canvasSize.width * 0.82 // 82% of canvas width

// Create the image context
guard let context = CGContext(
    data: nil,
    width: Int(canvasSize.width),
    height: Int(canvasSize.height),
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    print("Failed to create context")
    exit(1)
}

// Set up the context
context.setShouldAntialias(true)
context.setAllowsAntialiasing(true)
context.interpolationQuality = .high

// Create accent color (from theme)
let accentColor = NSColor(displayP3Red: 0.945, green: 0.620, blue: 0.298, alpha: 1.0)

// Draw background
context.setFillColor(useInvertedColors ? accentColor.cgColor : NSColor.black.cgColor)
context.fill(CGRect(origin: .zero, size: canvasSize))

// Create SF Symbol configuration with monochrome rendering mode
let config = NSImage.SymbolConfiguration(pointSize: symbolSize, weight: .regular)
    .applying(.init(paletteColors: [useInvertedColors ? .white : accentColor]))

// Create the asterisk image
guard let asteriskImage = NSImage(systemSymbolName: "asterisk", accessibilityDescription: nil)?
    .withSymbolConfiguration(config) else {
    print("Failed to create asterisk symbol")
    exit(1)
}

// Calculate center position
let x = (canvasSize.width - symbolSize) / 2
let y = (canvasSize.height - symbolSize) / 2

// Create a temporary image for rotation
let tempImage = NSImage(size: canvasSize)
tempImage.lockFocus()

// Draw the symbol rotated (-45 degrees)
NSGraphicsContext.current?.cgContext.translateBy(x: canvasSize.width/2, y: canvasSize.height/2)
NSGraphicsContext.current?.cgContext.rotate(by: -.pi/4) // Negative for opposite direction
NSGraphicsContext.current?.cgContext.translateBy(x: -canvasSize.width/2, y: -canvasSize.height/2)

let drawRect = CGRect(x: x, y: y, width: symbolSize, height: symbolSize)
asteriskImage.draw(in: drawRect)

tempImage.unlockFocus()

// Draw the rotated image to our main context
if let cgImage = tempImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
    context.draw(cgImage, in: CGRect(origin: .zero, size: canvasSize))
}

// Create the final image
guard let outputImage = context.makeImage() else {
    print("Failed to create image")
    exit(1)
}

// Create bitmap representation
let imageRep = NSBitmapImageRep(cgImage: outputImage)

// Convert to PNG data
guard let pngData = imageRep.representation(using: .png, properties: [:]) else {
    print("Failed to create PNG data")
    exit(1)
}

// Get the desktop path
let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
let outputURL = desktopURL.appendingPathComponent("GotamaIcon.png")

// Write to file
do {
    try pngData.write(to: outputURL)
    print("Icon saved to: \(outputURL.path)")
} catch {
    print("Failed to write file: \(error)")
    exit(1)
} 