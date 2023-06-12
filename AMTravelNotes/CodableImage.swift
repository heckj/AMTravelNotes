//
//  CodableImage.swift
//  AMTravelNotes
//
//  Created by Joseph Heck on 6/11/23.
//

import Foundation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct CodableImage: Codable {
    enum CodingKeys: CodingKey {
        case data
        case scale
    }

    #if os(iOS)
    let image: UIImage?

    init(image: UIImage) {
        self.image = image
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let scale = try container.decode(CGFloat.self, forKey: .scale)
        let data = try container.decode(Data.self, forKey: .data)
        image = UIImage(data: data, scale: scale)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let image = image {
            try container.encode(image.pngData(), forKey: .data)
            try container.encode(image.scale, forKey: .scale)
        }
    }

    #elseif os(macOS)
    let image: NSImage?

    init(image: NSImage) {
        self.image = image
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let data = try container.decode(Data.self, forKey: .data)
        image = NSImage(data: data)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let image = image {
            try container.encode(image.pngData(), forKey: .data)
        }
    }

    #endif
}
