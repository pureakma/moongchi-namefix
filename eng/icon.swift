import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
// Run from the repository root. Writes the Icon Composer document that Xcode compiles into the
// app icon: macOS 26 and later draw it full size in the system shape, and Xcode derives the
// bitmap icon for macOS 14 and 15 from the same document.
// A bitmap-only icon is shown shrunk on a gray plate by macOS 26 and later.
let folder = URL(fileURLWithPath: CommandLine.arguments[1])
let assets = folder.appendingPathComponent("Assets")
try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
let sourceURL = URL(fileURLWithPath: CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "assets/branding/NameFix-Original.png")
guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
      let artwork = CGImageSourceCreateImageAtIndex(source, 0, nil), artwork.width == artwork.height else {
    fatalError("A readable square source icon is required")
}
// The artwork is preserved as one full-canvas layer; the system supplies the outline.
let pixels = 1024
let ctx = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: pixels * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.interpolationQuality = .high
ctx.draw(artwork, in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
let dest = CGImageDestinationCreateWithURL(assets.appendingPathComponent("artwork.png") as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, ctx.makeImage()!, nil); guard CGImageDestinationFinalize(dest) else { exit(1) }
// The fill only shows where the artwork's own rounded corners fall inside the system shape,
// so it matches the artwork's background. No glass, highlight or shadow is added to the artwork.
let document: [String: Any] = [
    "fill": ["solid": "srgb:0.06275,0.21961,0.49412,1.00000"],
    "groups": [[
        "layers": [["glass": false, "image-name": "artwork.png", "name": "artwork"]],
        "shadow": ["kind": "none", "opacity": 0.5],
        "specular": false,
        "translucency": ["enabled": false, "value": 0.5]
    ]],
    "supported-platforms": ["squares": ["macOS"]]
]
try JSONSerialization.data(withJSONObject: document, options: [.prettyPrinted, .sortedKeys]).write(to: folder.appendingPathComponent("icon.json"))
