//
//  Document+Path.swift
//  AMTravelNotes
//
//  Created by Joseph Heck on 3/24/23.
//

import Automerge
import Foundation

class DocumentCache {
    static var objId: [String: (ObjId, ObjType)] = [:]
}

enum PathParseError: Error {
    case invalidPathElement(String)
}

extension Document {
    public func lookupPath(path: String) throws -> ObjId? {
        if path.first == "." {
            if let cacheResult = DocumentCache.objId[path] {
                return cacheResult.0
            }
        } else {
            if let cacheResult = DocumentCache.objId["." + path] {
                return cacheResult.0
            }
        }
        // breaks up the provided path, breaking on '.' and copying the results into their own Strings
        let bits = path.split(separator: ".").map { String($0) }
        if bits.isEmpty {
            return ObjId.ROOT
        }
        return try lookupSubPath(bits, basePath: "", from: ObjId.ROOT)
    }

    private func lookupSubPath(_ pathList: [String], basePath: String, from obj: ObjId) throws -> ObjId? {
        guard let pathPiece = pathList.first,
              let firstChar: Character = pathPiece.first
        else {
            return obj
        }
        let remainingPathPieces = Array(pathList[1...])

        if firstChar.isNumber,
           let parsedIndexValue = UInt64(pathPiece)
        {
            // ?? We probably need to verify we're not requesting beyond end of index here - need to check in tests
            if let value = try get(obj: obj, index: parsedIndexValue) {
                switch value {
                case let .Object(objId, objType):
                    let extendedPath: String = [basePath, pathPiece].joined(separator: ".")
                    DocumentCache.objId[extendedPath] = (objId, objType)
                    return try lookupSubPath(remainingPathPieces, basePath: extendedPath, from: objId)
                case .Scalar:
                    return nil
                }
            } else {
                // path is a valid request, there's just nothing there
                return nil
            }
        } else if firstChar.isASCII,
                  firstChar.isLetter
        {
            if let value = try get(obj: obj, key: String(pathPiece)) {
                switch value {
                case let .Object(objId, objType):
                    let extendedPath: String = [basePath, pathPiece].joined(separator: ".")
                    DocumentCache.objId[extendedPath] = (objId, objType)
                    return try lookupSubPath(remainingPathPieces, basePath: extendedPath, from: objId)
                case .Scalar:
                    return nil
                }
            } else {
                // path is a valid request, there's just nothing there
                return nil
            }
        } else {
            throw PathParseError.invalidPathElement(String(pathPiece))
        }
    }
}

extension Sequence where Element == Automerge.PathElement {
    func stringPath() -> String {
        map { pathElement in
            switch pathElement.prop {
            case let .Index(idx):
                return String(idx)
            case let .Key(key):
                return key
            }
        }.joined(separator: ".")
    }
}
