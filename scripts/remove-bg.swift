#!/usr/bin/env swift
// Remove the background from an image using Vision's foreground-instance mask.
// Usage: swift scripts/remove-bg.swift <input.png> [output.png]
// Requires macOS 14+ (this runs on your Mac, independent of the app's deploy target).

import Foundation
import AppKit
import Vision
import CoreImage

let args = CommandLine.arguments
guard args.count >= 2 else {
    print("Usage: swift scripts/remove-bg.swift <input> [output]")
    exit(1)
}
let inputPath = args[1]
let outputPath = args.count >= 3 ? args[2] : "mascot.png"

guard let nsImage = NSImage(contentsOfFile: inputPath),
      let tiff = nsImage.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let cg = bitmap.cgImage else {
    print("Could not load image at \(inputPath)")
    exit(1)
}

guard #available(macOS 14.0, *) else {
    print("Needs macOS 14+ for foreground masking.")
    exit(1)
}

let ci = CIImage(cgImage: cg)
let request = VNGenerateForegroundInstanceMaskRequest()
let handler = VNImageRequestHandler(cgImage: cg)

do {
    try handler.perform([request])
    guard let result = request.results?.first else {
        print("No foreground subject found.")
        exit(1)
    }
    let maskBuffer = try result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler)
    let mask = CIImage(cvPixelBuffer: maskBuffer)

    let blend = CIFilter(name: "CIBlendWithMask")!
    blend.setValue(ci, forKey: kCIInputImageKey)
    blend.setValue(CIImage(color: .clear).cropped(to: ci.extent), forKey: kCIInputBackgroundImageKey)
    blend.setValue(mask, forKey: kCIInputMaskImageKey)

    guard let output = blend.outputImage else { print("Blend failed"); exit(1) }
    let ctx = CIContext()
    guard let outCG = ctx.createCGImage(output, from: ci.extent) else { print("Render failed"); exit(1) }

    let rep = NSBitmapImageRep(cgImage: outCG)
    guard let png = rep.representation(using: .png, properties: [:]) else { print("PNG encode failed"); exit(1) }
    try png.write(to: URL(fileURLWithPath: outputPath))
    print("✓ Wrote transparent image to \(outputPath)")
} catch {
    print("Error: \(error)")
    exit(1)
}
