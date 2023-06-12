//
//  NSImage+pngData.swift
//  AMTravelNotes
//
//  Created by Joseph Heck on 6/11/23.
//

import Foundation
#if os(macOS)
import AppKit

extension NSImage {
    public func pngData(
        size: CGSize? = nil,
        imageInterpolation: NSImageInterpolation = .high
    ) -> Data? {
        let internalSize: CGSize
        if let size {
            internalSize = size
        } else {
            internalSize = self.size
        }

        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(internalSize.width),
            pixelsHigh: Int(internalSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bitmapFormat: [],
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }
        bitmap.size = internalSize

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSGraphicsContext.current?.imageInterpolation = imageInterpolation
        draw(
            in: NSRect(origin: .zero, size: internalSize),
            from: .zero,
            operation: .copy,
            fraction: 1.0
        )
        NSGraphicsContext.restoreGraphicsState()

        return bitmap.representation(using: .png, properties: [:])
    }
}
#endif
