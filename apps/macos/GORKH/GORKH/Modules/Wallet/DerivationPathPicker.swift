import SwiftUI

struct DerivationPathPicker: View {
    @Binding var derivationPath: DerivationPath

    private let options: [DerivationPath] = [
        .defaultSolana,
        try! DerivationPath("m/44'/501'/0'"),
        try! DerivationPath("m/44'/501'/1'/0'"),
        try! DerivationPath("m/44'/501'/2'/0'")
    ]

    var body: some View {
        Picker("Derivation", selection: Binding(
            get: { derivationPath.rawValue },
            set: { rawValue in
                if let path = try? DerivationPath(rawValue) {
                    derivationPath = path
                }
            }
        )) {
            ForEach(options) { path in
                Text(label(for: path)).tag(path.rawValue)
            }
        }
        .pickerStyle(.menu)
    }

    private func label(for path: DerivationPath) -> String {
        switch path.rawValue {
        case "m/44'/501'/0'/0'":
            return "Account 0 - \(path.rawValue)"
        case "m/44'/501'/0'":
            return "Account 0 root - \(path.rawValue)"
        case "m/44'/501'/1'/0'":
            return "Account 1 - \(path.rawValue)"
        case "m/44'/501'/2'/0'":
            return "Account 2 - \(path.rawValue)"
        default:
            return path.rawValue
        }
    }
}
