# MongoDBVapor
A library for building applications with [MongoDB](https://www.mongodb.com/) + [Vapor](https://vapor.codes/).

- [Documentation](#documentation)
- [Bugs / Feature Requests](#bugs---feature-requests)
- [Installation](#installation)
  * [Step 1: Install Required System Libraries (Linux Only)](#step-1--install-required-system-libraries--linux-only-)
  * [Step 2: Install the library](#step-2--install-the-library)
- [Example Usage](#example-usage)
  * [Configure global settings](#configure-global-settings)
  * [Use MongoDB in a Request Handler](#use-mongodb-in-a-request-handler)
  * [Working with Extended JSON](#working-with-extended-json)

## Documentation
### The latest documentation for the library is available [here](https://mongodb.github.io/mongodb-vapor/).

### You can find a complete example project built using this library [here](https://github.com/mongodb/mongo-swift-driver/tree/main/Examples/VaporExample)!

## Bugs / Feature Requests
Think you've found a bug? Want to see a new feature in `mongodb-vapor`? Please open a case in our issue management tool, JIRA:

1. Create an account and login: [jira.mongodb.org](https://jira.mongodb.org)
2. Navigate to the SWIFT project: [jira.mongodb.org/browse/SWIFT](https://jira.mongodb.org/browse/SWIFT)
3. Click **Create Issue** - Please provide as much information as possible about the issue and how to reproduce it.

Bug reports in JIRA for all driver projects (i.e. NODE, PYTHON, CSHARP, JAVA) and the
Core Server (i.e. SERVER) project are **public**.

## Installation
This library works with **Swift 5.2+** , and supports Linux and macOS usage. The minimum macOS version required is **10.15**.

Installation is supported via [Swift Package Manager](https://swift.org/package-manager/).

### Step 1: Install Required System Libraries (Linux Only)
The driver vendors and wraps the MongoDB C driver (`libmongoc`), which depends on a number of external C libraries when built in Linux environments. As a result, these libraries must be installed on your system in order to build MongoSwift.

To install those libraries, please follow the [instructions](http://mongoc.org/libmongoc/current/installing.html#prerequisites-for-libmongoc) from `libmongoc`'s documentation.

### Step 2: Install the library
Add this package along with Vapor as dependencies in your project's `Package.swift` file:

```swift
// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "VaporExample",
    platforms: [
        .macOS(.v10_15)
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor", .upToNextMajor(from: "4.7.0")),
        .package(url: "https://github.com/mongodb/mongodb-vapor", .upToNextMajor(from: "1.0.0"))
    ],
    targets: [
        .target(
            name: "App",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "MongoDBVapor", package: "mongodb-vapor")
            ]
        ),
        .target(name: "Run", dependencies: [
            .target(name: "App"),
            .product(name: "MongoDBVapor", package: "mongodb-vapor")
        ])
    ]
)
```

Then run `swift build` to download, compile, and link all your dependencies.

## Example Usage
### You can find a complete example project built using this library [here](https://github.com/mongodb/mongo-swift-driver/tree/main/Examples/VaporExample). 

To summarize the available features:

### Configure global settings

In `Run/main.swift`, add:
```swift
import MongoDBVapor

// Configure the app for using a MongoDB server at the provided connection string.
try app.mongoDB.configure("mongodb://localhost:27017")

defer {
    // Cleanup the application's MongoDB data.
    app.mongoDB.cleanup()
    // Clean up the driver's global state. The driver will no longer be usable from this program after this method is
    // called.
    cleanupMongoSwift()
}
```

### Use MongoDB in a Request Handler
For collections you plan to access frequently, we recommend adding computed properties in an extension to `Request`
to provide easy access, like:
```swift
extension Request {
    /// A collection with an associated `Codable` type `Kitten`.
    var kittenCollection: MongoCollection<Kitten> {
        self.mongoDB.client.db("home").collection("kittens", withType: Kitten.self)
    }
}
```

**Any client, database, or collection object you access via `Request.mongoDB` will automatically return `EventLoopFuture`s 
on the same `EventLoop` the `Request` is being handled on, simplifying thread safety concerns and improving performance
by removing the need to `hop` the returned futures.**

You can then use these in request handlers as follows:
```swift
/// Handles a request to load the list of kittens.
app.get("kittens") { req -> EventLoopFuture<[Kitten]> in
    req.kittenCollection.find().flatMap { cursor in
        cursor.toArray()
    }
}

app.post("kittens") { req -> EventLoopFuture<Response> in
    let newKitten = try req.content.decode(Kitten.self)
    return req.kittenCollection.insertOne(newKitten)
        .map { _ in Response(status: .created) }
}
```

### Perform one-time setup or teardown code
If you have one-time code you'd like to run each time your application starts up, e.g. in `Run/main.swift`, you can
use the global client, accessible via `Application.mongoDB`:
```swift
// Configure the app for using a MongoDB server at the provided connection string.
try app.mongoDB.configure("mongodb://localhost:27017")
let coll = app.mongoDB.client.db("home").collection("kittens")
// creates a unique index if it doesn't exist already.
_ = try coll.createIndex(["name": 1], indexOptions: IndexOptions(unique: true)).wait()
```

### Working with Extended JSON
If you'd like to use `ExtendedJSONEncoder` and `ExtendedJSONDecoder` for encoding/decoding JSON requests/responses, in  `App/configure.swift`, add:
```swift
// Use `ExtendedJSONEncoder` and `ExtendedJSONDecoder` for encoding/decoding `Content`.
ContentConfiguration.global.use(encoder: ExtendedJSONEncoder(), for: .json)
ContentConfiguration.global.use(decoder: ExtendedJSONDecoder(), for: .json)
```
Note that this is currently required if you want to use `BSONDocument` as a `Content` type and e.g.
directly return `BSONDocument`s from request handlers, because `BSONDocument` does not yet support 
being encoded/decoded via `JSONEncoder` and `JSONDecoder`.

For more information on JSON interoperation in general with the driver, see our 
[JSON interop guide](https://mongodb.github.io/swift-bson/docs/current/SwiftBSON/json-interop.html).
