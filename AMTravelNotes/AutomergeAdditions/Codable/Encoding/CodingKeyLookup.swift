import class Automerge.Document
import struct Automerge.ObjId

// import enum Automerge.ObjType
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

/// An enumeration that represents the type of encoding container.
enum LookupType {
    /// A keyed container.
    case Key
    /// An un-keyed container.
    case Index
    /// A single-value container.
    case Value
}

func retrieveObjectId(
    doc: Document,
    path: [any CodingKey],
    type: LookupType
) -> Result<(ObjId, SchemaPathElement), Error> {
    // This method returns a Result type because the Codable protocol constrains the container initializers to not
    // throw.
    // Instead we stash the lookup failure into the container, and throw the relevant error on any of the .encode()
    // methods, which do throw.
    // This defers the error condition, and the container is essentially invalid in this state,
    // but it provides a smoother integration with Codable.

    // Path scenarios by the type of Codable container that invokes the lookup.
    //
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

    // Iterate through the existential CodingKey array and convert them to explicit SchemaPathElement
    // instances that we can use to look up an ObjectId.
    let convertedPath = path.map { codingkey in
        SchemaPathElement(codingkey)
    }

    do {
        let (objId, pathPiece) = try retrieveSchemaPath(doc: doc, convertedPath, basePath: [], from: ObjId.ROOT)
        return .success((objId, pathPiece))
    } catch {
        return .failure(error)
    }
}

/// A function that iterates through a path, creating schema structure as necessary within an Automerge document, to
/// return an object Id for a codable container type.
/// - Parameters:
///   - doc: The automerge document to operate against.
///   - pathList: The path to be iterated.
///   - basePath: The path that has already been iterated.
///   - obj: The object Id that maps to the current state path iteration.
///   - readOnly: A Boolean value that indicates whether this function read or create schema elements as necessary.
/// - Throws: An error condition attempting to look up, and potentially create, the schema path within an Automerge
/// document.
/// - Returns: A tuple of the object Id and the key or index, represented by a ``SchemaPathElement``, on that objectId.
private func retrieveSchemaPath(
    doc: Document,
    _ pathList: [SchemaPathElement],
    basePath: [SchemaPathElement],
    from obj: ObjId,
    readOnly: Bool = true
) throws -> (ObjId, SchemaPathElement) {
    // Iterate through the list, pulling off the first element from the path, and extending
    // the `basePath` for the next (possible) iteration.
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

    // Determine if the current path element we're processing is an index or key.
    if let indexValue = pathPiece.intValue {
        // If it's an index, verify that it doesn't represent an element beyond the end of an existing list.
        if indexValue > doc.length(obj: obj) {
            throw CodingKeyLookupError
                .indexOutOfBounds("Index value \(indexValue) is beyond the length: \(doc.length(obj: obj))")
        }
        // Look up Automerge `Value` matching this index within the list
        if let value = try doc.get(obj: obj, index: UInt64(indexValue)) {
            switch value {
            case let .Object(objId, objType):
//                EncoderPathCache.upsert(extendedPath, value: (objId, objType))
                // if the type of Object is Text, we should error here if there are more pieces to look up
                if !remainingPathPieces.isEmpty, objType == .Text {
                    // If the looked up Value is a Text node, then it's a leaf on the schema structure.
                    // If there's remaining values to be looked up, the overall path is invalid.
                    throw CodingKeyLookupError
                        .pathExtendsThroughText(
                            "Path at \(extendedPath) is a Text object, which is not a container - and the path has additional elements: \(remainingPathPieces)."
                        )
                }
                return try retrieveSchemaPath(doc: doc, remainingPathPieces, basePath: extendedPath, from: objId)
            case .Scalar:
                // If the looked up Value is a Scalar value, then it's a leaf on the schema structure.
                // If there's remaining values to be looked up, the overall path is invalid.
                if !remainingPathPieces.isEmpty {
                    throw CodingKeyLookupError
                        .pathExtendsThroughScalar(
                            "Path at \(extendedPath) is a single value, not a container - and the path has additional elements: \(remainingPathPieces)."
                        )
                }
                return (obj, pathPiece)
            }
        } else {
            // the current value in the Automerge document at this index position is `nil`
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
                        return try retrieveSchemaPath(
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
                        return try retrieveSchemaPath(
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

    } else { // if let indexValue = pathPiece.intValue was false, this path element is a key
        let keyValue = pathPiece.stringValue

        if let value = try doc.get(obj: obj, key: keyValue) {
            switch value {
            case let .Object(objId, objType):
//                EncoderPathCache.upsert(extendedPath, value: (objId, objType))

                // If the looked up Value is a Text node, then it's a leaf on the schema structure.
                // If there's remaining values to be looked up, the overall path is invalid.
                if !remainingPathPieces.isEmpty, objType == .Text {
                    throw CodingKeyLookupError
                        .pathExtendsThroughText(
                            "Path at \(extendedPath) is a Text object, which is not a container - and the path has additional elements: \(remainingPathPieces)."
                        )
                }
                return try retrieveSchemaPath(doc: doc, remainingPathPieces, basePath: extendedPath, from: objId)
            case .Scalar:
                // If the looked up Value is a Scalar value, then it's a leaf on the schema structure.
                // If there's remaining values to be looked up, the overall path is invalid.
                if !remainingPathPieces.isEmpty {
                    throw CodingKeyLookupError
                        .pathExtendsThroughScalar(
                            "Path at \(extendedPath) is a single value, not a container - and the path has additional elements: \(remainingPathPieces)."
                        )
                }
                return (obj, pathPiece)
            }
        } else { // value returned from doc.get() is nil
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
                        return try retrieveSchemaPath(
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
                        return try retrieveSchemaPath(
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
