import MongoDBVapor
import Nimble
import Vapor
import XCTest
import XCTVapor

// Note: these tests assume you have a standalone mongod running at localhost:27017.
final class MongoDBVaporTests: XCTestCase {
    override class func tearDown() {
        cleanupMongoSwift()
    }

    func testSetUpAndCleanUp() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        try app.mongoDB.configure()
        expect(app.mongoDB.client).toNot(beNil())
        expect(try app.mongoDB.client.listDatabases().wait()).toNot(throwError())

        let client1 = app.mongoDB.client
        let client2 = app.mongoDB.client
        expect(client1).to(equal(client2))

        app.mongoDB.cleanup()
        expect(try app.mongoDB.client.listDatabases().wait()).to(throwError())
    }

    func testRequestClientAccess() throws {
        let app = Application(.testing)
        defer {
            app.mongoDB.cleanup()
            app.shutdown()
        }

        func configure(_ app: Application) throws {
            try app.mongoDB.configure()
            routes(app)
        }

        func routes(_ app: Application) {
            app.get("listDatabases") { req -> EventLoopFuture<[String]> in
                let client = req.mongoDB.client
                expect(client.eventLoop) === req.eventLoop
                let res = client.listDatabaseNames()
                expect(res.eventLoop) === req.eventLoop
                return res
            }
        }

        try configure(app)

        let testHandler = { (res: XCTHTTPResponse) in
            let dbs = try res.content.decode([String].self)
            expect(dbs).toNot(beEmpty())
        }

        // cycle through event loops
        for _ in 1...System.coreCount {
            try app.test(.GET, "listDatabases", afterResponse: testHandler)
        }
    }

    func testExtendedJSONContent() throws {
        ContentConfiguration.global.use(encoder: ExtendedJSONEncoder(), for: .json)
        ContentConfiguration.global.use(decoder: ExtendedJSONDecoder(), for: .json)
        defer {
            ContentConfiguration.global.use(encoder: JSONEncoder(), for: .json)
            ContentConfiguration.global.use(decoder: JSONDecoder(), for: .json)
        }

        let app = Application(.testing)
        defer {
            app.shutdown()
        }
        struct TestStruct: Content, Equatable, Validatable {
            let _id: BSONObjectID

            static func validations(_ validations: inout Validations) {
                validations.add("_id", as: BSONObjectID.self, is: .valid, required: true)
            }
        }

        let test = TestStruct(
            _id: BSONObjectID()
        )

        let testDoc = try BSONEncoder().encode(test)
        let testExtJSON = try String(decoding: ExtendedJSONEncoder().encode(test), as: UTF8.self)

        // test returning a custom Codable type.
        app.get("test") { _ in test }
        try app.test(.GET, "test") { res in
            // the response type should have been automatically serialized to extJSON.
            expect(res.body.string).to(equal(testExtJSON))
        }

        // test returning a BSONDocument.
        app.get("testDoc") { _ in testDoc }
        try app.test(.GET, "testDoc") { res in
            // the response type should have been automatically serialized to extJSON.
            expect(res.body.string).to(equal(testExtJSON))
        }

        app.post("test") { req -> Response in
            // the request's body should be extended JSON.
            expect(req.body.string).to(equal(testExtJSON))
            // we should be able to decode the request content into our original type.
            expect(try req.content.decode(TestStruct.self)).to(equal(test))
            // we should also be able to decode the request content into a BSONDocument.
            expect(try req.content.decode(BSONDocument.self)).to(equal(testDoc))
            return Response(status: .ok)
        }

        try app.test(
            .POST,
            "test",
            beforeRequest: { req in
                // manually add request data
                try req.content.encode(test)
            },
            afterResponse: { res in
                expect(res.status).to(equal(.ok))
            }
        )

        app.post("test-validate") { req -> Response in
            try TestStruct.validate(content: req)
            return Response(status: .ok)
        }

        try app.test(
            .POST,
            "test-validate",
            beforeRequest: { req in
                try req.content.encode(test)
            },
            afterResponse: { res in
                expect(res.status).to(equal(.ok))
            }
        )
    }
}
