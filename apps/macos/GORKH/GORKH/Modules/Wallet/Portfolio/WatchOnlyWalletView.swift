import SwiftUI

struct WatchOnlyWalletView: View {
    @EnvironmentObject private var walletManager: WalletManager
    @State private var editingProfileID: UUID?
    @State private var editedLabel = ""
    @State private var editedTag = ""
    @State private var removeConfirmation = ""

    private var watchOnlyProfiles: [WalletProfile] {
        walletManager.profiles
            .filter(\.isWatchOnly)
            .sorted { $0.label < $1.label }
    }

    var body: some View {
        GorkhPanel("Watch-only Wallets") {
            VStack(alignment: .leading, spacing: 12) {
                if watchOnlyProfiles.isEmpty {
                    Text("No watch-only addresses are tracked yet.")
                        .foregroundStyle(GorkhColors.secondaryText)
                } else {
                    ForEach(watchOnlyProfiles) { profile in
                        watchOnlyRow(profile)
                    }
                }
            }
        }
    }

    private func watchOnlyRow(_ profile: WalletProfile) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(profile.label)
                            .font(.headline)
                            .foregroundStyle(GorkhColors.primaryText)
                        GorkhStatusChip(title: "Watch-only", systemImage: "eye", color: GorkhColors.warning)
                        if let tag = profile.colorTag, !tag.isEmpty {
                            GorkhStatusChip(title: tag, systemImage: "tag", color: GorkhColors.accent)
                        }
                    }
                    Text(profile.publicAddress)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(GorkhColors.secondaryText)
                        .textSelection(.enabled)
                }

                Spacer()

                Button {
                    editingProfileID = profile.id
                    editedLabel = profile.label
                    editedTag = profile.colorTag ?? ""
                    removeConfirmation = ""
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .buttonStyle(.gorkhSecondary)
            }

            if editingProfileID == profile.id {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        TextField("Label", text: $editedLabel)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 220)
                        TextField("Tag", text: $editedTag)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 160)
                        Button {
                            walletManager.updateWalletLabel(profileID: profile.id, label: editedLabel, tag: editedTag)
                            editingProfileID = nil
                        } label: {
                            Label("Save", systemImage: "checkmark")
                        }
                        .buttonStyle(.gorkhPrimary)
                        Button {
                            editingProfileID = nil
                        } label: {
                            Label("Cancel", systemImage: "xmark")
                        }
                        .buttonStyle(.gorkhSecondary)
                    }

                    HStack {
                        TextField("Type REMOVE WATCH", text: $removeConfirmation)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 220)
                        Button {
                            walletManager.removeWatchOnlyWallet(profileID: profile.id, confirmation: removeConfirmation)
                            if removeConfirmation == "REMOVE WATCH" {
                                editingProfileID = nil
                                removeConfirmation = ""
                            }
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                        .buttonStyle(.gorkhSecondary)
                    }
                }
            }
        }
        .padding(12)
        .background(GorkhColors.panelElevated.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
