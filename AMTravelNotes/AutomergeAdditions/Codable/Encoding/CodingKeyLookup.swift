import class Automerge.Document
import struct Automerge.ObjId
import enum Automerge.ObjType
import enum Automerge.Prop
// import protocol Automerge.ScalarValueRepresentable

// enum EncoderPathCache {
//    typealias CacheKey = [SchemaPathElement]
//    static var cache: [CacheKey: (ObjId, ObjType)] = [:]
//
//    static func upsert(_ key: CacheKey, value: (ObjId, ObjType)) {
//        if cache[key] == nil {
//            cache[key] = value
//        }
//    }
// }

enum LookupType {
    case Key
    case Index
    case Value
}

public enum CodingKeyLookupError: Error {
    /// The path element is not valid.
    case invalidPathElement(String)
    /// The path element, structured as a Index location, doesn't include an index value.
    case emptyListIndex(String)
    /// The list index requested was longer than the list in the Document.
    case indexOutOfBounds(String)

    case invalidValueLookup(String)
    case invalidIndexLookup(String)
    case pathExtendsThroughText(String)
    case pathExtendsThroughScalar(String)

    // schema is missing beyond a certain point - only in readOnly mode
    case schemaMissing(String)
}

func lookupObjectId(
    doc: Document,
    path: [any CodingKey],
    type: LookupType
) -> Result<(ObjId, SchemaPathElement), Error> {
    // returns a Result type because we can't throw within a Container initializer in Encodable
    // Instead we stash the "Oh shit, this ain't gunna work" details into the container, and pitch
    // a pitch on any of the .encode() methods, which DO throw.

    // [] + Key -> ObjId.ROOT
    // [] + Index = error
    // [] + Value = error
    // [foo] + Value = ObjId.Root
    // [foo] + Index = error
    // [foo] + Key = ObjId.lookup(/Root/foo)   (container)
    // [1] + (Value|Index|Key) = error (root is always a map)
    // [foo, 1] + Value = /Root/foo, index 1
    // [foo, 1] + Index = /Root/foo, index 1   (container)
    // [foo, 1] + Key = /Root/foo, index 1     (container)
    // [foo, bar] + Value = /Root/foo, key bar
    // [foo, bar] + Index = /Root/foo, key bar (container)
    // [foo, bar] + Key = /Root/foo, key bar   (container)
    if path.isEmpty {
        switch type {
        case .Key:
            return .success((ObjId.ROOT, SchemaPathElement.ROOT))
        case .Index:
            return .failure(
                CodingKeyLookupError
                    .invalidIndexLookup("An empty path refers to ROOT and is always a map.")
            )
        case .Value:
            return .failure(
                CodingKeyLookupError
                    .invalidValueLookup("An empty path refers to ROOT and is always a map.")
            )
        }
    }

    // iterate through the existential CodingKey array and convert them to explicit SchemaPathElement
    // instances that we can use to look up an ObjectId.
    let convertedPath = path.map { codingkey in
        SchemaPathElement(codingkey)
    }

    do {
        let (objId, pathPiece) = try lookupSubPath(doc: doc, convertedPath, basePath: [], from: ObjId.ROOT)
        return .success((objId, pathPiece))
    } catch {
        return .failure(error)
    }
}

private func lookupSubPath(
    doc: Document,
    _ pathList: [SchemaPathElement],
    basePath: [SchemaPathElement],
    from obj: ObjId,
    readOnly: Bool = true
) throws -> (ObjId, SchemaPathElement) {
    guard let pathPiece = pathList.first else {
        if let previousPiece = basePath.last {
            return (obj, previousPiece)
        } else {
            fatalError("Both the path and base path empty - can't look anything up or return a valid result")
        }
    }

    let remainingPathPieces = Array(pathList[1...])
    var extendedPath = basePath
    extendedPath.append(pathPiece)

    if let indexValue = pathPiece.intValue {
        if indexValue > doc.length(obj: obj) {
            throw CodingKeyLookupError
                .indexOutOfBounds("Index value \(indexValue) is beyond the length: \(doc.length(obj: obj))")
        }
        if let value = try doc.get(obj: obj, index: UInt64(indexValue)) {
            switch value {
            case let .Object(objId, objType):
//                EncoderPathCache.upsert(extendedPath, value: (objId, objType))
                // if the type of Object is Text, we should error here if there are more pieces to look up
                if !remainingPathPieces.isEmpty, objType == .Text {
                    throw CodingKeyLookupError
                        .pathExtendsThroughText(
                            "Path at \(extendedPath) is a Text object, which is not a container - and the path has additional elements."
                        )
                }
                return try lookupSubPath(doc: doc, remainingPathPieces, basePath: extendedPath, from: objId)
            case .Scalar:
                if !remainingPathPieces.isEmpty {
                    throw CodingKeyLookupError
                        .pathExtendsThroughScalar(
                            "Path at \(extendedPath) is a single value, not a container - and the path has additional elements."
                        )
                }
                return (obj, pathPiece)
            }
        } else {
            if readOnly {
                // path is a valid request, there's just nothing there
                throw CodingKeyLookupError
                    .schemaMissing("Nothing in schema exists at \(extendedPath) - look u returns nil")
            } else {
                if let nextPiece = remainingPathPieces.first {
                    // there are more pieces, infer what we need to build from the next piece
                    if let indexValue = nextPiece.intValue {
                        // create a list
                        let newObjectId = try doc.putObject(obj: obj, index: UInt64(indexValue), ty: .List)
                        // add to cache
//                        EncoderPathCache.upsert(extendedPath, value: (newObjectId, .List))
                        // carry on with remaining path elements
                        return try lookupSubPath(
                            doc: doc,
                            remainingPathPieces,
                            basePath: extendedPath,
                            from: newObjectId
                        )
                    } else {
                        // create an object
                        let newObjectId = try doc.putObject(obj: obj, key: nextPiece.stringValue, ty: .Map)
                        // add to cache
//                        EncoderPathCache.upsert(extendedPath, value: (newObjectId, .Map))
                        // carry on with remaining path elements
                        return try lookupSubPath(
                            doc: doc,
                            remainingPathPieces,
                            basePath: extendedPath,
                            from: newObjectId
                        )
                    }
                } else {
                    // No remaining pieces in the path, go ahead and return where we are
                    return (obj, pathPiece)
                }
            }
        }

    } else {
        let keyValue = pathPiece.stringValue

        if let value = try doc.get(obj: obj, key: keyValue) {
            switch value {
            case let .Object(objId, objType):
//                EncoderPathCache.upsert(extendedPath, value: (objId, objType))
                // if the type of Object is Text, we should error here if there are more pieces to look up
                if !remainingPathPieces.isEmpty, objType == .Text {
                    throw CodingKeyLookupError
                        .pathExtendsThroughText(
                            "Path at \(extendedPath) is a Text object, which is not a container - and the path has additional elements."
                        )
                }
                return try lookupSubPath(doc: doc, remainingPathPieces, basePath: extendedPath, from: objId)
            case .Scalar:
                if !remainingPathPieces.isEmpty {
                    throw CodingKeyLookupError
                        .pathExtendsThroughScalar(
                            "Path at \(extendedPath) is a single value, not a container - and the path has additional elements."
                        )
                }
                return (obj, pathPiece)
            }
        } else {
            if readOnly {
                // path is a valid request, there's just nothing there
                throw CodingKeyLookupError
                    .schemaMissing("Nothing in schema exists at \(extendedPath) - look u returns nil")
            } else {
                if let nextPiece = remainingPathPieces.first {
                    // there are more pieces, infer what we need to build from the next piece
                    if let indexValue = nextPiece.intValue {
                        // create a list
                        let newObjectId = try doc.putObject(obj: obj, index: UInt64(indexValue), ty: .List)
                        // add to cache
//                        EncoderPathCache.upsert(extendedPath, value: (newObjectId, .List))
                        // carry on with remaining path elements
                        return try lookupSubPath(
                            doc: doc,
                            remainingPathPieces,
                            basePath: extendedPath,
                            from: newObjectId
                        )
                    } else {
                        // create an object
                        let newObjectId = try doc.putObject(obj: obj, key: nextPiece.stringValue, ty: .Map)
                        // add to cache
//                        EncoderPathCache.upsert(extendedPath, value: (newObjectId, .Map))
                        // carry on with remaining path elements
                        return try lookupSubPath(
                            doc: doc,
                            remainingPathPieces,
                            basePath: extendedPath,
                            from: newObjectId
                        )
                    }
                } else {
                    // No remaining pieces in the path, go ahead and return where we are
                    return (obj, pathPiece)
                }
            }
        }
    }
}
