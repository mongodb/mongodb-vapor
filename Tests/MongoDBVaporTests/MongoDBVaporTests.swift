@testable import MongoDBVapor
import Nimble
import Vapor
import XCTest

final class MongoDBVaporTests: XCTestCase {
    func testSetUpAndCleanUp() throws {
        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)
        let app = Application(env)

        try app.configureMongoDB()
        expect(app.mongoClient).toNot(beNil())
        expect(try app.mongoClient.listDatabases().wait()).toNot(throwError())

        try app.cleanupMongoDB()
        expect(try app.mongoClient.listDatabases().wait()).to(throwError())
        try app.shutdown()
    }
}
