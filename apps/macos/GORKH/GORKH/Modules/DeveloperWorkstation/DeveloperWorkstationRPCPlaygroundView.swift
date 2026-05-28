import SwiftUI

struct DeveloperWorkstationRPCPlaygroundView: View {
    @Binding var rpcMethod: WorkstationRPCMethod
    @Binding var rpcAddress: String
    @Binding var rpcSignature: String
    @Binding var encodedTransaction: String
    let selectedCluster: WorkstationCluster

    var body: some View {
        GorkhPanel("RPC Playground") {
            Picker("Method", selection: $rpcMethod) {
                ForEach(WorkstationRPCMethod.allCases) { method in
                    Text(method.title).tag(method)
                }
            }
            .pickerStyle(.menu)
            DeveloperWorkstationKeyValueRow(key: "Risk label", value: rpcMethod.isReadOnly && !rpcMethod.isBroadScan ? "Read-only preset" : "Blocked or routed through guarded panel")
            DeveloperWorkstationLabeledTextField(label: "Address", text: $rpcAddress, prompt: "Required for address methods")
            DeveloperWorkstationLabeledTextField(label: "Signature", text: $rpcSignature, prompt: "Required for signature methods")
            DeveloperWorkstationLabeledTextField(label: "Encoded transaction/message", text: $encodedTransaction, prompt: "Required for simulate/getFeeForMessage")

            let request = WorkstationRPCPlaygroundRequest(
                method: rpcMethod,
                cluster: selectedCluster,
                address: rpcAddress.isEmpty ? nil : rpcAddress,
                signature: rpcSignature.isEmpty ? nil : rpcSignature,
                encodedTransaction: encodedTransaction.isEmpty ? nil : encodedTransaction,
                amountSOL: nil
            )
            let permission = WorkstationRPCPlaygroundService.validate(request)
            WorkstationStatusChip(
                title: permission.isAllowed ? "Allowed" : "Blocked",
                systemImage: permission.isAllowed ? "checkmark.circle" : "lock",
                color: permission.isAllowed ? GorkhColors.success : GorkhColors.warning
            )
            Text(permission.message)
                .font(.caption)
                .foregroundStyle(permission.isAllowed ? GorkhColors.success : GorkhColors.warning)
            Text("Saved presets are bounded to reviewed read-only methods. sendTransaction, custom method text, and broad scans are blocked. requestAirdrop is routed through the faucet guard only.")
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
        }
    }
}
