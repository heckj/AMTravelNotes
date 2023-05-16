import class Automerge.Document
import struct Automerge.ObjId

// I think the cache would be useful for larger encoding scenarios - and it looks
// like I can "stash" it as a static reference on the AutomergeEncoderImpl class, accessing
// it as needed during the lookups that happen on Container creation.

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
enum EncodingContainerType {
    /// A keyed container.
    case Key
    /// An un-keyed container.
    case Index
    /// A single-value container.
    case Value
}

/// A type that represents the encoder strategy to establish or error on differences in existing Automerge documents as
/// compared to expected encoding.
public enum SchemaStrategy {
    // What we do while looking up if there's a schema mismatch:

    /// Creates schema where none exists, errors on schema mismatch.
    ///
    /// Basic schema checking for containers that creates relevant objects in Automerge at the relevant path doesn't
    /// exist.
    /// If there is something in an existing Automerge document that doesn't match the type of container, or if the path
    /// is a leaf-node
    /// (a scalar value, or a Text instance), then the lookup captures the schema error for later presentation.
    case `default`

    /// Creates schema, irregardless of existing schema.
    ///
    /// Disregards any existing schema that currently exists in the Automerge document and overwrites the path elements
    /// as
    /// the encoding progresses. This option will potentially change the schema within an Automerge document.
    case override

    /// Allows updating of values only.
    /// If the schema does not pre-exist in the format that the encoder expects, the lookup doesn't create schema and
    /// captures an error for later presentation.
    case readonly
}

// Keyed container - I need an ObjectId that matches the keyed container (object) to write into.
//   on `encode()`, I'll be encoding with a key thats provided on methods.
//    - if needed, I should be extending the schema to add the container

// Un-keyed container - I need an ObjectId that matches the un-keyed container (list) to write into.
//   on `encode()`, I'll be encoding with a key thats provided on methods
//    - if needed, I should be extending the array size to add the container

// Single-value container - I need an ObjectId with the containing object AND the key (or index)
//   on `encode()`, I'll need to know the key or index to determine what method to use to write into
//     and Automerge objectId with the relevant value.

// Encoder Configuration Option (effects encode() methods):

// (extra-check)
// value-type-checked: As we call encode(), verify that the underlying types (ScalarValue, Text, etc)
// in Automerge aren't incompatible with the type we are encoding - at least for the leaf nodes.

/// Returns an Automerge objectId for the location within the document.
///
/// The function looks up Automerge schema while optionally creating schema if needed, and reporting on errors with
/// conflicting schema.
/// Control the pattern of when to create schema and what errors to throw by setting the `strategy` property.
///
/// - Parameters:
///   - doc: The Automerge document to look up
///   - path: An array of instances conforming to CodingKey that make up the schema path.
///   - type: The container type for the lookup, which effects what is returned and at what level of the path.
///   - strategy: The strategy for creating schema during encoding if it doesn't exist or conflicts with existing
/// schema. The strategy defaults to ``SchemaStrategy/default``.
/// - Returns: A result type that contains a tuple of an Automerge object Id of the relevant container and the final
/// CodingKey value, or an error if the retrieval failed or there was conflicting schema within in the document.
func retrieveObjectId(
    doc: Document,
    path: [CodingKey],
    containerType: EncodingContainerType,
    strategy: SchemaStrategy = .default
) -> Result<(ObjId, SchemaPathElement), Error> {
    // This method returns a Result type because the Codable protocol constrains the
    // container initializers to not throw on initialization.
    // Instead we stash the lookup failure into the container, and throw the relevant
    // error on any call to one of the `.encode()` methods, which do throw.
    // This defers the error condition, and the container is essentially invalid in this
    // state, but it provides a smoother integration with Codable.

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

    // Pre-allocate an array the same length as `path` for ObjectId lookups
    var matchingObjectIds: [Int: ObjId] = [:]
    matchingObjectIds.reserveCapacity(path.count)

    // - Efficiency boost using a cache
    // Iterate from the N-1 end of path, backwards - checking [] -> (ObjectId, ObjType) cache,
    // checking until we get a positive hit from the cache. Worst case there'll be nothing in
    // the cache and we iterate to the bottom. Save that as the starting cursor position.
    var startingPosition = 0
    var previousObjectId = ObjId.ROOT

    // initial conditions if we're handed an empty path
    if path.isEmpty {
        switch containerType {
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

    // Iterate the cursor position forward doing lookups against the Automerge document
    // until we get to the second-to-last element. This range ensures that we're iterating
    // over "expected containers"
    for position in startingPosition ..< (path.count - 1) {
        // Strategy to use while creating schema:
        // (default)
        // schema-create-on-nil: If the schema *doesn't* exist - nil lookups when searched - create
        // the relevant schema as it goes. This doesn't account for any specific value types or type checking.
        //
        // schema-error-on-type-mismatch: If schema in Automerge is a scalar value, Text, or mis-matched
        // list/object types, throw an error instead of overwriting the schema.

        // (!override!)
        // schema-overwrite: Disregard any schema that currently exists and overwrite values as needed to
        // establish the schema that is being encoded.

        // (?readonly?)
        // read-only/super-double-strict: Only allow encoding into schema that is ALREADY present within
        // Automerge. Adding additional values (to a map, or to a list) would be invalid in these cases.
        // In a large sense, it's an "update values only" kind of scenario.

        // Determine if the current path element we're processing is an index or key.
        if let indexValue = path[position].intValue {
            // If it's an index, verify that it doesn't represent an element beyond the end of an existing list.
            if indexValue > doc.length(obj: previousObjectId) {
                if strategy == .readonly {
                    return .failure(
                        CodingKeyLookupError
                            .indexOutOfBounds(
                                "Index value \(indexValue) is beyond the length: \(doc.length(obj: previousObjectId)) and schema is read-only"
                            )
                    )
                } else if indexValue > (doc.length(obj: previousObjectId) + 1) {
                    return .failure(
                        CodingKeyLookupError
                            .indexOutOfBounds(
                                "Index value \(indexValue) is too far beyond the length: \(doc.length(obj: previousObjectId)) to append a new item."
                            )
                    )
                }
            }

            // Look up Automerge `Value` matching this index within the list
            do {
                if let value = try doc.get(obj: previousObjectId, index: UInt64(indexValue)) {
                    switch value {
                    case let .Object(objId, objType):
                        //                EncoderPathCache.upsert(extendedPath, value: (objId, objType))
                        // if the type of Object is Text, we should error here because the schema can't extend through a
                        // leaf node
                        if objType == .Text {
                            // If the looked up Value is a Text node, then it's a leaf on the schema structure.
                            // If there's remaining values to be looked up, the overall path is invalid.
                            return .failure(
                                CodingKeyLookupError
                                    .pathExtendsThroughText(
                                        "Path at \(path[0 ... position]) is a Text object, which is not a container - and the path has additional elements: \(path[(position + 1)...])."
                                    )
                            )
                        }
                        matchingObjectIds[position] = objId
                        previousObjectId = objId
                    case .Scalar:
                        // If the looked up Value is a Scalar value, then it's a leaf on the schema structure.
                        return .failure(
                            CodingKeyLookupError
                                .pathExtendsThroughScalar(
                                    "Path at \(path[0 ... position]) is a single value, not a container - and the path has additional elements: \(path[(position + 1)...])."
                                )
                        )
                    }
                } else { // value returned from the lookup in Automerge at this position is `nil`
                    if strategy == .readonly {
                        // path is a valid request, there's just nothing there
                        return .failure(
                            CodingKeyLookupError
                                .schemaMissing(
                                    "Nothing in schema exists at \(path[0 ... position]) - look u returns nil"
                                )
                        )
                    } else {
                        // Look up the kind of "next path" element - list or object.
                        if let _ = path[position + 1].intValue {
                            // need to create a list
                            let newObjectId = try doc.putObject(
                                obj: previousObjectId,
                                index: UInt64(indexValue),
                                ty: .List
                            )
                            matchingObjectIds[position] = newObjectId
                            previousObjectId = newObjectId
                            // add to cache
                            //                        EncoderPathCache.upsert(extendedPath, value: (newObjectId, .List))
                        } else {
                            // need to create an object
                            let newObjectId = try doc.putObject(
                                obj: previousObjectId,
                                key: path[position + 1].stringValue,
                                ty: .Map
                            )
                            matchingObjectIds[position] = newObjectId
                            previousObjectId = newObjectId
                            // add to cache
                            //                        EncoderPathCache.upsert(extendedPath, value: (newObjectId, .Map))
                            // carry on with remaining path elements
                        }
                    }
                }
            } catch {
                return .failure(error)
            }
        } else { // path[position] is a string-based key
            let keyValue = path[position].stringValue
            do {
                if let value = try doc.get(obj: previousObjectId, key: keyValue) {
                    switch value {
                    case let .Object(objId, objType):
                        //                EncoderPathCache.upsert(extendedPath, value: (objId, objType))

                        // If the looked up Value is a Text node, then it's a leaf on the schema structure.
                        // If there's remaining values to be looked up, the overall path is invalid.
                        if objType == .Text {
                            return .failure(
                                CodingKeyLookupError
                                    .pathExtendsThroughText(
                                        "Path at \(path[0 ... position]) is a Text object, which is not a container - and the path has additional elements: \(path[(position + 1)...])."
                                    )
                            )
                        }
                        matchingObjectIds[position] = objId
                        previousObjectId = objId
                    case .Scalar:
                        // If the looked up Value is a Scalar value, then it's a leaf on the schema structure.
                        // If there's remaining values to be looked up, the overall path is invalid.
                        return .failure(
                            CodingKeyLookupError
                                .pathExtendsThroughScalar(
                                    "Path at \(path[0 ... position]) is a single value, not a container - and the path has additional elements: \(path[(position + 1)...])."
                                )
                        )
                    }
                } else { // value returned from doc.get() is nil
                    if strategy == .readonly {
                        // path is a valid request, there's just nothing there
                        return .failure(
                            CodingKeyLookupError
                                .schemaMissing(
                                    "Nothing in schema exists at \(path[0 ... position]) - look u returns nil"
                                )
                        )
                    } else {
                        // Look up the kind of "next path" element - list or object.
                        if let _ = path[position + 1].intValue {
                            // create a list
                            let newObjectId = try doc.putObject(obj: previousObjectId, key: keyValue, ty: .List)
                            matchingObjectIds[position] = newObjectId
                            previousObjectId = newObjectId
                            // add to cache
                            //                        EncoderPathCache.upsert(extendedPath, value: (newObjectId, .List))
                        } else {
                            // create an object
                            let newObjectId = try doc.putObject(obj: previousObjectId, key: keyValue, ty: .Map)
                            matchingObjectIds[position] = newObjectId
                            previousObjectId = newObjectId
                            // add to cache
                            //                        EncoderPathCache.upsert(extendedPath, value: (newObjectId, .Map))
                            // carry on with remaining path elements
                        }
                    }
                }
            } catch {
                return .failure(error)
            }
        }
    }

    // Then what we do depends on the type of lookup.
    // - on SingleValueContainer, we return the second-to-last objectId and the key and/or Index
    // - on KeyedContainer or UnkeyedContainer, we look up and return the final objectId
    let finalpiece = path[path.count - 1]
    switch containerType {
    case .Index:
        return .failure(CodingKeyLookupError.unexpectedLookupFailure("unimplemented"))
    case .Key:
        return .failure(CodingKeyLookupError.unexpectedLookupFailure("unimplemented"))
    case .Value:
        guard let containerObjectId = matchingObjectIds[path.count - 2] else {
            fatalError("objectId lookups failed to identify object Id for the second to last element in path: \(path)")
        }
        return .success((containerObjectId, SchemaPathElement(finalpiece)))
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
//    func retrieveSchemaPath(
//        doc: Document,
//        _ pathList: [SchemaPathElement],
//        basePath: [SchemaPathElement],
//        from obj: ObjId,
//        readOnly: Bool = true
//    ) throws -> (ObjId, SchemaPathElement) {
//        // Iterate through the list, pulling off the first element from the path, and extending
//        // the `basePath` for the next (possible) iteration.
//        guard let pathPiece = pathList.first else {
//            if let previousPiece = basePath.last {
//                return (obj, previousPiece)
//            } else {
//                fatalError("Both the path and base path empty - can't look anything up or return a valid result")
//            }
//        }
//
//        let remainingPathPieces = Array(pathList[1...])
//        var extendedPath = basePath
//        extendedPath.append(pathPiece)
//
//        // Determine if the current path element we're processing is an index or key.
//        if let indexValue = pathPiece.intValue {
//            // If it's an index, verify that it doesn't represent an element beyond the end of an existing list.
//            if indexValue > doc.length(obj: obj) {
//                throw CodingKeyLookupError
//                    .indexOutOfBounds("Index value \(indexValue) is beyond the length: \(doc.length(obj: obj))")
//            }
//            // Look up Automerge `Value` matching this index within the list
//            if let value = try doc.get(obj: obj, index: UInt64(indexValue)) {
//                switch value {
//                case let .Object(objId, objType):
//                    //                EncoderPathCache.upsert(extendedPath, value: (objId, objType))
//                    // if the type of Object is Text, we should error here if there are more pieces to look up
//                    if !remainingPathPieces.isEmpty, objType == .Text {
//                        // If the looked up Value is a Text node, then it's a leaf on the schema structure.
//                        // If there's remaining values to be looked up, the overall path is invalid.
//                        throw CodingKeyLookupError
//                            .pathExtendsThroughText(
//                                "Path at \(extendedPath) is a Text object, which is not a container - and the path has
//                                additional elements: \(remainingPathPieces)."
//                            )
//                    }
//                    return try retrieveSchemaPath(doc: doc, remainingPathPieces, basePath: extendedPath, from: objId)
//                case .Scalar:
//                    // If the looked up Value is a Scalar value, then it's a leaf on the schema structure.
//                    // If there's remaining values to be looked up, the overall path is invalid.
//                    if !remainingPathPieces.isEmpty {
//                        throw CodingKeyLookupError
//                            .pathExtendsThroughScalar(
//                                "Path at \(extendedPath) is a single value, not a container - and the path has
//                                additional elements: \(remainingPathPieces)."
//                            )
//                    }
//                    return (obj, pathPiece)
//                }
//            } else {
//                // the current value in the Automerge document at this index position is `nil`
//                if readOnly {
//                    // path is a valid request, there's just nothing there
//                    throw CodingKeyLookupError
//                        .schemaMissing("Nothing in schema exists at \(extendedPath) - look u returns nil")
//                } else {
//                    if let nextPiece = remainingPathPieces.first {
//                        // there are more pieces, infer what we need to build from the next piece
//                        if let indexValue = nextPiece.intValue {
//                            // create a list
//                            let newObjectId = try doc.putObject(obj: obj, index: UInt64(indexValue), ty: .List)
//                            // add to cache
//                            //                        EncoderPathCache.upsert(extendedPath, value: (newObjectId,
//                            /.List))
//                            // carry on with remaining path elements
//                            return try retrieveSchemaPath(
//                                doc: doc,
//                                remainingPathPieces,
//                                basePath: extendedPath,
//                                from: newObjectId
//                            )
//                        } else {
//                            // create an object
//                            let newObjectId = try doc.putObject(obj: obj, key: nextPiece.stringValue, ty: .Map)
//                            // add to cache
//                            //                        EncoderPathCache.upsert(extendedPath, value: (newObjectId,
//                            /.Map))
//                            // carry on with remaining path elements
//                            return try retrieveSchemaPath(
//                                doc: doc,
//                                remainingPathPieces,
//                                basePath: extendedPath,
//                                from: newObjectId
//                            )
//                        }
//                    } else {
//                        // No remaining pieces in the path, go ahead and return where we are
//                        return (obj, pathPiece)
//                    }
//                }
//            }
//
//        } else { // if let indexValue = pathPiece.intValue was false, this path element is a key
//            let keyValue = pathPiece.stringValue
//
//            if let value = try doc.get(obj: obj, key: keyValue) {
//                switch value {
//                case let .Object(objId, objType):
//                    //                EncoderPathCache.upsert(extendedPath, value: (objId, objType))
//
//                    // If the looked up Value is a Text node, then it's a leaf on the schema structure.
//                    // If there's remaining values to be looked up, the overall path is invalid.
//                    if !remainingPathPieces.isEmpty, objType == .Text {
//                        throw CodingKeyLookupError
//                            .pathExtendsThroughText(
//                                "Path at \(extendedPath) is a Text object, which is not a container - and the path has
//                                additional elements: \(remainingPathPieces)."
//                            )
//                    }
//                    return try retrieveSchemaPath(doc: doc, remainingPathPieces, basePath: extendedPath, from: objId)
//                case .Scalar:
//                    // If the looked up Value is a Scalar value, then it's a leaf on the schema structure.
//                    // If there's remaining values to be looked up, the overall path is invalid.
//                    if !remainingPathPieces.isEmpty {
//                        throw CodingKeyLookupError
//                            .pathExtendsThroughScalar(
//                                "Path at \(extendedPath) is a single value, not a container - and the path has
//                                additional elements: \(remainingPathPieces)."
//                            )
//                    }
//                    return (obj, pathPiece)
//                }
//            } else { // value returned from doc.get() is nil
//                if readOnly {
//                    // path is a valid request, there's just nothing there
//                    throw CodingKeyLookupError
//                        .schemaMissing("Nothing in schema exists at \(extendedPath) - look u returns nil")
//                } else {
//                    if let nextPiece = remainingPathPieces.first {
//                        // there are more pieces, infer what we need to build from the next piece
//                        if let indexValue = nextPiece.intValue {
//                            // create a list
//                            let newObjectId = try doc.putObject(obj: obj, index: UInt64(indexValue), ty: .List)
//                            // add to cache
//                            //                        EncoderPathCache.upsert(extendedPath, value: (newObjectId,
//                            /.List))
//                            // carry on with remaining path elements
//                            return try retrieveSchemaPath(
//                                doc: doc,
//                                remainingPathPieces,
//                                basePath: extendedPath,
//                                from: newObjectId
//                            )
//                        } else {
//                            // create an object
//                            let newObjectId = try doc.putObject(obj: obj, key: nextPiece.stringValue, ty: .Map)
//                            // add to cache
//                            //                        EncoderPathCache.upsert(extendedPath, value: (newObjectId,
//                            /.Map))
//                            // carry on with remaining path elements
//                            return try retrieveSchemaPath(
//                                doc: doc,
//                                remainingPathPieces,
//                                basePath: extendedPath,
//                                from: newObjectId
//                            )
//                        }
//                    } else {
//                        // No remaining pieces in the path, go ahead and return where we are
//                        return (obj, pathPiece)
//                    }
//                }
//            }
//        }
//    }
