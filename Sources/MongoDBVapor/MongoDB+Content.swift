import MongoSwift
import Vapor

// These extensions enable users to encode/decode their Content types to/from JSON using `ExtendedJSONEncoder` and
// `ExtendedJSONDecoder`. This is useful in cases where users are using one of our custom BSON types in their
// structs which does not currently support encoding/decoding via `JSONEncoder`/`JSONDecoder`.

// Note that in the case where additional userInfo is provided, a copy has to be made of the encoder/decoder and the
// info added to that, both for thread safety and to prevent the additional info from accidentally persisting. If
// the encoder/decoder has existing user info configured and one or more keys are set in both it and the user info
// provided to the method, the latter's values take precedence. This support is necessary for using Vapor's
// Validation module with these coders.

extension ExtendedJSONEncoder: ContentEncoder {
    public func encode<E: Encodable>(_ encodable: E, to body: inout ByteBuffer, headers: inout HTTPHeaders) throws {
        try self.encode(encodable, to: &body, headers: &headers, userInfo: [:])
    }

    public func encode<E: Encodable>(_ encodable: E, to body: inout ByteBuffer, headers: inout HTTPHeaders, userInfo: [CodingUserInfoKey: Any]) throws {
        let encoder: ExtendedJSONEncoder
        if userInfo.isEmpty {
            encoder = self
        } else {
            encoder = ExtendedJSONEncoder()
            encoder.format = self.format
            encoder.userInfo = self.userInfo.merging(userInfo, uniquingKeysWith: { $1 })
        }

        headers.contentType = .json
        var buffer = try encoder.encodeBuffer(encodable)
        body.writeBuffer(&buffer)
    }
}

extension ExtendedJSONDecoder: ContentDecoder {
    public func decode<D: Decodable>(_: D.Type, from body: ByteBuffer, headers: HTTPHeaders) throws -> D {
        try self.decode(D.self, from: body, headers: headers, userInfo: [:])
    }

    public func decode<D: Decodable>(_: D.Type, from body: ByteBuffer, headers _: HTTPHeaders, userInfo: [CodingUserInfoKey: Any]) throws -> D {
        let decoder: ExtendedJSONDecoder
        if userInfo.isEmpty {
            decoder = self
        } else {
            decoder = ExtendedJSONDecoder()
            decoder.userInfo = self.userInfo.merging(userInfo, uniquingKeysWith: { $1 })
        }

        return try decoder.decode(D.self, from: body)
    }
}

/// Enables `BSONDocument` to be used as a `Content` type when `ExtendedJSONEncoder`/`ExtendedJSONDecoder` are set as
/// the default JSON encoder/decoder for the application.
extension BSONDocument: Content {}
