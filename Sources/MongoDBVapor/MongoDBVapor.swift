import MongoSwift
import Vapor

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
        public private(set) var client: MongoClient {
            get {
                self.application.storage[MongoClientKey.self]!
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
            self.client = try MongoClient(connectionString, using: self.application.eventLoopGroup, options: options)
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
                try self.client.syncClose()
            } catch {
                self.application.logger.error("Failed to shut down MongoDB client: \(error)")
            }
        }
    }
}

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
