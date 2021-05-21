import MongoSwift
import Vapor

/**
 * An extension to Vapor's `Application` type to add support for configuring your application to interact with a
 * MongoDB deployment. All of the API is namespaced under the `.mongoDB` property on the `Application.MongoDB` type.
 * This extension supports the following:
 *
 * - Configuring a global MongoDB client for your application via `Application.MongoDB.configure(_:options:)`, for
 *   example:
 * ```
 * myApp.mongoDB.configure("mongodb://localhost:27017")
 * ```
 *
 * - Accessing a global client via `Application.MongoDB.client`, for example:
 * ```
 * myApp.mongoDB.client.listDatabases()
 * ```
 *
 * - Cleaning up the global client when your application is shutting down via `Application.MongoDB.cleanup()`,
 *   for example:
 * ```
 * myApp.mongDB.cleanup()
 * ```
 *
 * See `Application.MongoDB` for further details.
 */
extension Application {
    /// Returns an instance of `MongoDB`, providing access to MongoDB APIs for use at the `Application` level.
    public var mongoDB: MongoDB {
        MongoDB(application: self)
    }

    /// A type providing access to MongoDB APIs for use at the `Application` level.
    public struct MongoDB {
        private struct MongoClientKey: StorageKey {
            typealias Value = MongoClient
        }

        /**
         * A global `MongoClient` for use throughout the application. This client is not accessible until
         * `Application.mongoDB.configure()` has been called. This client is primarily intended for use in application
         * setup/teardown code and may return futures on any event loop within the application's `EventLoopGroup`.
         * Within `Request` handlers, it is preferable to use `Request.mongoDB.client` as that will return a client
         * which uses the same `EventLoop` as the `Request`.
         */
        public var client: MongoClient {
            // swiftlint:disable:next force_unwrapping
            self._client! // this is fine assuming it is only accessed after a successful call to `configure()`
        }

        /// Private version of the client to ensure we can safely handle cases where it is optional. This allows users
        /// to e.g. unconditionally call `app.mongoDB.cleanup()` without issue even if initialization failed. We
        /// provide the less-safe non-optional public `client` for user convenience.
        private var _client: MongoClient? {
            get {
                self.application.storage[MongoClientKey.self]
            }
            nonmutating set {
                self.application.storage[MongoClientKey.self] = newValue
            }
        }

        private let application: Application

        internal init(application: Application) {
            self.application = application
        }

        /**
         * Configures a global `MongoClient` with the specified options. The client may then be accessed via the
         * `mongoDB.client` computed property on the `Application`. The client will use the `Application`'s
         * `EventLoopGroup` for executing operations.
         *
         * For example:
         * ````
         *  let app = Application() // a Vapor Application
         *  try app.mongoDB.configure() // configures a MongoClient
         *  app.mongoDB.client.listDatabases() // a client is now accessible via the Application
         * ````
         *
         * - Parameters:
         *   - connectionString: the connection string to connect to.
         *   - options: optional `MongoClientOptions` to use for the client.
         *
         * - Throws:
         *   - A `MongoError.InvalidArgumentError` if the connection string passed in is improperly formatted.
         */
        public func configure(
            _ connectionString: String = "mongodb://localhost:27017",
            options: MongoClientOptions? = nil
        ) throws {
            addWrappingLibraryMetadata(name: "MongoDBVapor", version: versionString)
            self._client = try MongoClient(connectionString, using: self.application.eventLoopGroup, options: options)
        }

        /**
         * Handles MongoDB related cleanup. Call this method when shutting down your application.
         * If an error occurs while closing the client, it will be logged via the `Application`'s logger.
         * For example:
         * ````
         *  app.mongoDB.cleanup()
         *  app.shutdown()
         * ````
         *
         * It is an error to attempt to use the driver after calling this method.
         */
        public func cleanup() {
            do {
                try self._client?.syncClose()
            } catch {
                self.application.logger.error("Failed to shut down MongoDB client: \(error)")
            }
        }
    }
}

/**
 * An extension to Vapor's `Request` type to add support for conveniently accessing MongoDB core types e.g.
 * e.g. clients, databases, and collections which return futures on on the same `EventLoop` which the `Request` is
 * on.
 *
 * This extension provides a `Request.mongoDB.client` property which you can use as follows from within a `Request`
 * handler:
 * ```
 * req.mongoDB.client.db("home").collection("kittens", withType: Kitten.self).insertOne(myKitten)
 * ```
 * We recommend utilizing this API to add extensions to `Request` for MongoDB databases and collections you frequently
 * access, for example:
 * ```
 * extension Request {
 *     /// A collection with an associated `Codable` type `Kitten`.
 *     var kittenCollection: MongoCollection<Kitten> {
 *         self.client.db("home").collection("kittens", withType: Kitten.self)
 *     }
 * }
 * ```
 */
extension Request {
    /// Returns an instance of `MongoDB`, providing access to MongoDB APIs for use at the `Request` level.
    public var mongoDB: MongoDB {
        MongoDB(request: self)
    }

    /// A type providing access to MongoDB APIs for use at the `Request` level.
    public struct MongoDB {
        internal let request: Request

        internal init(request: Request) {
            self.request = request
        }

        /// A MongoDB client which will return `EventLoopFuture`s on the same `EventLoop` as the `Request`.
        public var client: EventLoopBoundMongoClient {
            let globalClient = self.request.application.mongoDB.client
            return globalClient.bound(to: self.request.eventLoop)
        }
    }
}
