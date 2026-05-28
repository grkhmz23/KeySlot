import SwiftUI
import AppKit

struct DeveloperWorkstationView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var store = DeveloperWorkstationStore()

    var body: some View {
        GeometryReader { proxy in
            workstationLayout(showSidebar: proxy.size.width >= 900, compact: proxy.size.width < 720)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            store.startSession()
            consumePendingDeveloperWorkstationSectionIfNeeded()
        }
        .onChange(of: appState.pendingDeveloperWorkstationSection) {
            consumePendingDeveloperWorkstationSectionIfNeeded()
        }
    }

    private func consumePendingDeveloperWorkstationSectionIfNeeded() {
        if let section = appState.consumePendingDeveloperWorkstationSection() {
            store.selectionState.selectedSection = section
        }
        if let section = store.agentFrontendState.pendingWorkstationSection {
            store.agentFrontendState.pendingWorkstationSection = nil
            store.selectionState.selectedSection = section
        }
    }

    private func workstationLayout(showSidebar: Bool, compact: Bool) -> some View {
        HStack(spacing: 0) {
            if showSidebar {
                workstationSidebar

                Divider().overlay(GorkhColors.border)
            }

            VStack(spacing: 0) {
                header(compact: compact)

                sectionToolbar(compact: compact)

                Divider().overlay(GorkhColors.border)

                ScrollView {
                    sectionBody
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func header(compact: Bool) -> some View {
        let titleBlock = VStack(alignment: .leading, spacing: 8) {
            Text("Developer Workstation")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(GorkhColors.primaryText)
            Text("Solana builder workspace for import, IDL review, account decode, logs, RPC reads, compute simulation, and gated localnet/devnet program ops.")
                .font(.callout)
                .foregroundStyle(GorkhColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Text("Imported projects start untrusted. Build scripts can run local code, so build/deploy/upgrade/close remain locked until explicit trust and localnet/devnet policy checks pass.")
                .font(.caption)
                .foregroundStyle(GorkhColors.warning)
                .fixedSize(horizontal: false, vertical: true)
        }

        let clusterControls = VStack(alignment: compact ? .leading : .trailing, spacing: 8) {
            Picker("Cluster", selection: $store.selectionState.selectedCluster) {
                ForEach(WorkstationCluster.allCases) { cluster in
                    Text(cluster.title).tag(cluster)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 180)
            WorkstationStatusChip(
                title: store.selectionState.selectedCluster.programOpsMode.title,
                systemImage: store.selectionState.selectedCluster.programOpsMode == .enabled ? "checkmark.shield" : "lock.shield",
                color: store.selectionState.selectedCluster.programOpsMode == .enabled ? GorkhColors.success : GorkhColors.warning
            )
        }

        return Group {
            if compact {
                VStack(alignment: .leading, spacing: 14) {
                    titleBlock
                    clusterControls
                }
            } else {
                HStack(alignment: .top, spacing: 14) {
                    titleBlock

                    Spacer(minLength: 12)

                    clusterControls
                }
            }
        }
        .padding(18)
    }

    private var workstationSidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Workstation")
                .font(.headline)
                .foregroundStyle(GorkhColors.primaryText)
                .padding(.horizontal, 14)
                .padding(.top, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(DeveloperWorkstationSection.allCases) { section in
                        workstationSectionButton(section)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 14)
            }

            Divider().overlay(GorkhColors.border)

            VStack(alignment: .leading, spacing: 8) {
                Text(store.selectionState.selectedCluster.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(GorkhColors.primaryText)
                    .lineLimit(1)
                Text(store.selectionState.selectedCluster.programOpsMode.title)
                    .font(.caption2)
                    .foregroundStyle(store.selectionState.selectedCluster.programOpsMode == .enabled ? GorkhColors.success : GorkhColors.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
        .frame(width: 190)
        .background(GorkhColors.sidebar)
    }

    private func workstationSectionButton(_ section: DeveloperWorkstationSection) -> some View {
        Button {
            store.selectionState.selectedSection = section
        } label: {
            HStack(spacing: 8) {
                Image(systemName: section.systemImage)
                    .frame(width: 18)
                Text(section.title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Spacer(minLength: 0)
            }
            .font(.caption)
            .foregroundStyle(store.selectionState.selectedSection == section ? GorkhColors.primaryText : GorkhColors.secondaryText)
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(store.selectionState.selectedSection == section ? GorkhColors.panel : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .help(section.title)
    }

    private func sectionToolbar(compact: Bool) -> some View {
        Group {
            if compact {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        if store.selectionState.selectedSection != .overview {
                            Button {
                                store.selectionState.selectedSection = .overview
                            } label: {
                                Label("Back to Overview", systemImage: "chevron.left")
                            }
                            .buttonStyle(.bordered)
                        }

                        Spacer()

                        sectionMenu
                    }

                    sectionTitleBlock
                }
            } else {
                HStack(spacing: 10) {
                    if store.selectionState.selectedSection != .overview {
                        Button {
                            store.selectionState.selectedSection = .overview
                        } label: {
                            Label("Back to Overview", systemImage: "chevron.left")
                        }
                        .buttonStyle(.bordered)
                    }

                    sectionTitleBlock

                    Spacer()

                    sectionMenu
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 12)
    }

    private var sectionTitleBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(store.selectionState.selectedSection.title)
                .font(.headline)
                .foregroundStyle(GorkhColors.primaryText)
            Text(store.selectionState.selectedSection.subtitle)
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var sectionMenu: some View {
        Picker("Go to", selection: $store.selectionState.selectedSection) {
            ForEach(DeveloperWorkstationSection.allCases) { section in
                Text(section.title).tag(section)
            }
        }
        .pickerStyle(.menu)
        .frame(width: 190)
    }

    @ViewBuilder
    private var sectionBody: some View {
        DeveloperWorkstationSectionContentView(
            store: store,
            dateFormatter: DeveloperWorkstationStore.dateFormatter
        )
    }
}

struct WorkstationStatusChip: View {
    let title: String
    let systemImage: String
    let color: Color

    var body: some View {
        GorkhStatusChip(title: title, systemImage: systemImage, color: color)
    }
}
