import MongoSwift
import Vapor

extension Application {
    /// A global `MongoClient` for use throughout the application. The client is thread-safe
    /// and backed by a pool of connections so it should be shared across event loops.
    public var mongoClient: MongoClient {
        get {
            self.storage[MongoClientKey.self]!
        }
        set {
            self.storage[MongoClientKey.self] = newValue
        }
    }

    private struct MongoClientKey: StorageKey {
        // swiftlint:disable nesting
        typealias Value = MongoClient
    }

    /**
     * Configures a global `MongoClient` with the specified options. The client will use the application's
     * `EventLoopGroup` for executing operations.
     *
     * - Parameters:
     *   - connectionString: the connection string to connect to.
     *   - options: optional `MongoClientOptions` to use for the client.
     *
     * - Throws:
     *   - A `MongoError.InvalidArgumentError` if the connection string passed in is improperly formatted.
     */
    public func configureMongoDB(
        _ connectionString: String = "mongodb://localhost:27017",
        options: MongoClientOptions? = nil
    ) throws {
        let client = try MongoClient(connectionString, using: self.eventLoopGroup, options: options)
        self.mongoClient = client
    }

    /// Handles MongoDB related cleanup. Call this method when shutting down your application.
    public func cleanupMongoDB() {
        do {
            try self.mongoClient.syncClose()
        } catch {
            app.logger.error("Failed to shut down MongoDB client: \(error)")
        }
        cleanupMongoSwift()
    }
}
