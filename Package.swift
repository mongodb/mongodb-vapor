// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "mongodb-vapor",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .library(name: "MongoDBVapor", targets: ["MongoDBVapor"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Quick/Nimble.git", .upToNextMajor(from: "8.0.0")),
        .package(url: "https://github.com/mongodb/mongo-swift-driver", .upToNextMajor(from: "1.3.1")),
        .package(url: "https://github.com/vapor/vapor", .upToNextMajor(from: "4.0.0"))
    ],
    targets: [
        .target(
            name: "MongoDBVapor",
            dependencies: [
                .product(name: "MongoSwift", package: "mongo-swift-driver"),
                .product(name: "Vapor", package: "vapor")
            ]
        ),
        .testTarget(
            name: "MongoDBVaporTests",
            dependencies: [
                "MongoDBVapor",
                "Nimble",
                .product(name: "XCTVapor", package: "vapor")
            ]
        ),
    ]
)
