//
//  AutomergeDecoder.swift
//  AMTravelNotes
//
//  Created by Joseph Heck on 5/4/23.
//

import Foundation

public struct AutomergeDecoder {
    public var userInfo: [CodingUserInfoKey: Any] = [:]

    public init() {}

//    // decode JSON from a stream of bytes (array of bytes)
//    @inlinable public func decode<T: Decodable, Bytes: Collection>(_: T.Type, from bytes: Bytes)
//        throws -> T where Bytes.Element == UInt8
//    {
//        do {
//            let json = try JSONParser().parse(bytes: bytes)
//            return try self.decode(T.self, from: json)
//        } catch let error as JSONError {
//            throw error.decodingError
//        }
//    }
//
//    // decode JSON from a JSONValue
//    @inlinable public func decode<T: Decodable>(_: T.Type, from json: JSONValue) throws -> T {
//        let decoder = JSONDecoderImpl(userInfo: userInfo, from: json, codingPath: [])
//        return try decoder.decode(T.self)
//    }
}
