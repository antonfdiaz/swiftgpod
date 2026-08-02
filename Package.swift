// swift-tools-version: 6.0
import PackageDescription

#if arch(arm64)
let homebrewPrefix = "/opt/homebrew"
#elseif arch(x86_64)
let homebrewPrefix = "/usr/local"
#else
#error("swiftgpod supports Homebrew on Apple Silicon and Intel Macs only.")
#endif

let package = Package(
    name: "libgpod",
    products: [
        .library(name: "GPod", targets: ["GPod"]),
        .library(name: "Clibgpod", targets: ["Clibgpod"]),
    ],
    targets: [
        .systemLibrary(
            name: "CGLib",
            pkgConfig: "glib-2.0",
            providers: [
                .brew(["glib"]),
                .apt(["libglib2.0-dev"]),
            ]
        ),
        .target(
            name: "Clibgpod",
            dependencies: ["CGLib"],
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
                    // gobject-2.0
                    "-I\(homebrewPrefix)/include",
                    "-I\(homebrewPrefix)/include/glib-2.0",
                    "-I\(homebrewPrefix)/lib/glib-2.0/include",
                    // libplist
                    "-I\(homebrewPrefix)/include",
                    // libxml2
                    "-I/usr/include/libxml2",
                ]),
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-L\(homebrewPrefix)/lib",
                    "-lgobject-2.0",
                    "-lgmodule-2.0",
                    "-lglib-2.0",
                    "-lintl",
                    "-lplist-2.0",
                    "-lsqlite3",
                    "-lxml2",
                    "-lz",
                    "-lm",
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
