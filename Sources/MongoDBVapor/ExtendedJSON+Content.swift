import MongoSwift
import Vapor

// These extension enable users to encode/decode their Content types to/from JSON using `ExtendedJSONEncoder` and
// `ExtendedJSONDecoder`. This is useful in cases where users are using one of our custom BSON types in their
// structs which does not currently support encoding/decoding via `JSONEncoder`/`JSONDecoder`.

extension ExtendedJSONEncoder: ContentEncoder {
    public func encode<E>(_ encodable: E, to body: inout ByteBuffer, headers: inout HTTPHeaders) throws
        where E: Encodable
    {
        headers.contentType = .json
        try body.writeBytes(self.encode(encodable))
    }
}

extension ExtendedJSONDecoder: ContentDecoder {
    public func decode<D>(_: D.Type, from body: ByteBuffer, headers _: HTTPHeaders) throws -> D
        where D: Decodable
    {
        let data = body.getData(at: body.readerIndex, length: body.readableBytes) ?? Data()
        return try self.decode(D.self, from: data)
    }
}
