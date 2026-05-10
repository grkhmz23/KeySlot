import Foundation

struct WorkstationSampleProject: Codable, Equatable {
    let name: String
    let relativePath: String
    let expectedIDLPath: String
    let expectedArtifactPath: String

    static let anchorHelloWorld = WorkstationSampleProject(
        name: "Anchor Hello World",
        relativePath: "samples/anchor-hello-world",
        expectedIDLPath: "target/idl/hello_world.json",
        expectedArtifactPath: "target/deploy/hello_world.so"
    )
}
