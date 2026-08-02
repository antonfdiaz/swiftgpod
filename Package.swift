// swift-tools-version: 6.0
import PackageDescription
import Foundation

let packageRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path
let dependenciesRoot = "\(packageRoot)/Dependencies"

let package = Package(
    name: "libgpod",
    products: [
        .library(name: "GPod", targets: ["GPod"]),
        .library(name: "Clibgpod", targets: ["Clibgpod"]),
    ],
    targets: [
        .target(
            name: "Clibgpod",
            path: "src",
            exclude: [
                "gchecksum.c",
                "gchecksum.h",
            ],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("."),
                .define("HAVE_CONFIG_H", to: "1"),
                .unsafeFlags([
                    "-I/usr/include/libxml2",
                ]),
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-L\(dependenciesRoot)/lib",
                    "-lgmodule-2.0",
                    "-lgobject-2.0",
                    "-lglib-2.0",
                    "-lpcre2-8",
                    "-lffi",
                    "-lintl",
                    "-lplist-2.0",
                    "-liconv",
                    "-lsqlite3",
                    "-lxml2",
                    "-lz",
                    "-lm",
                    "-framework", "Foundation",
                    "-framework", "CoreFoundation",
                    "-framework", "CoreServices",
                ]),
            ]
        ),
        .target(
            name: "GPod",
            dependencies: ["Clibgpod"],
            path: "Sources/GPod"
        ),
    ]
)
