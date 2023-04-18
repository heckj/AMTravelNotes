import Automerge
import Foundation

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

#if os(iOS)
extension UIImage: AutomergeRepresentable {
    public enum ImageConversionError: LocalizedError {
        case notdata(_ val: Value)
        case dataNotAnImage(_ data: Data)
        case noPNGRepresentation

        /// A localized message describing what error occurred.
        public var errorDescription: String? {
            switch self {
            case let .notdata(val):
                return "Failed to read the scalar value \(val) as a Boolean."
            case let .dataNotAnImage(data):
                return "Unable to read in data \(data) as an Image"
            case .noPNGRepresentation:
                return "The image provided does not provide a PNG representation."
            }
        }

        /// A localized message describing the reason for the failure.
        public var failureReason: String? { nil }
    }

    public static func fromValue(_ val: Value) throws -> Self {
        switch val {
        case let .Scalar(.Bytes(d)):
            guard let result = Self(data: d) else {
                throw ImageConversionError.dataNotAnImage(d)
            }
            return result
        default:
            throw ImageConversionError.notdata(val)
        }
    }

    public func toValue(doc _: Document, objId _: ObjId) throws -> Value {
        guard let data = pngData() else {
            throw ImageConversionError.noPNGRepresentation
        }
        return .Scalar(.Bytes(data))
    }
}

#elseif os(macOS)

extension NSImage: AutomergeRepresentable {
    public enum ImageConversionError: LocalizedError {
        case notdata(_ val: Value)
        case dataNotAnImage(_ data: Data)
        case noPNGRepresentation
        case noCGImageRepresentation

        /// A localized message describing what error occurred.
        public var errorDescription: String? {
            switch self {
            case let .notdata(val):
                return "Failed to read the scalar value \(val) as a Boolean."
            case let .dataNotAnImage(data):
                return "Unable to read in data \(data) as an Image"
            case .noPNGRepresentation:
                return "The image provided does not provide a PNG representation."
            case .noCGImageRepresentation:
                return "The image provided does not provide a PNG representation."
            }
        }

        /// A localized message describing the reason for the failure.
        public var failureReason: String? { nil }
    }

    public static func fromValue(_ val: Value) throws -> Self {
        switch val {
        case let .Scalar(.Bytes(d)):
            guard let result = Self(data: d) else {
                throw ImageConversionError.dataNotAnImage(d)
            }
            return result
        default:
            throw ImageConversionError.notdata(val)
        }
    }

    public func toValue(doc _: Document, objId _: ObjId) throws -> Value {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw ImageConversionError.noCGImageRepresentation
        }
        let newRep = NSBitmapImageRep(cgImage: cgImage)
        newRep.size = size
        guard let data = newRep.representation(using: .png, properties: [:]) else {
            throw ImageConversionError.noPNGRepresentation
        }
        return .Scalar(.Bytes(data))
    }
}
#endif
