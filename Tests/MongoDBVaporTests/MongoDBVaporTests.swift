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
}
