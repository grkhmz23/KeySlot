import Foundation

struct WorkstationSampleProject: Codable, Equatable {
    let name: String
    let relativePath: String
    let expectedIDLPath: String
    let expectedArtifactPath: String

    var path: String {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(relativePath, isDirectory: true)
            .path
    }

    static let anchorHelloWorld = WorkstationSampleProject(
        name: "Anchor Hello World",
        relativePath: "samples/anchor-hello-world",
        expectedIDLPath: "target/idl/hello_world.json",
        expectedArtifactPath: "target/deploy/hello_world.so"
    )
}
