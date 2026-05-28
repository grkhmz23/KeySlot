import SwiftUI

struct DeveloperWorkstationAccountDecoderView: View {
    @Binding var accountAddress: String
    @Binding var accountDataBase64: String
    @Binding var accountDecoderIDLAccountSelection: String
    let parsedIDL: WorkstationIDL?

    var body: some View {
        GorkhPanel("Account Decoder") {
            DeveloperWorkstationLabeledTextField(label: "Account address", text: $accountAddress, prompt: "Solana public key")
            DeveloperWorkstationLabeledTextField(label: "Account data base64", text: $accountDataBase64, prompt: "Optional account data fixture")
            if let parsedIDL, !parsedIDL.accounts.isEmpty {
                Picker("IDL account type", selection: $accountDecoderIDLAccountSelection) {
                    Text("Auto match discriminator").tag("__auto")
                    ForEach(parsedIDL.accounts) { account in
                        Text(account.name).tag(account.name)
                    }
                }
                .pickerStyle(.menu)
            }
            let idlAccount = selectedAccountDecoderIDLAccount()
            let result = WorkstationAccountDecoder.decode(
                WorkstationAccountDecodeRequest(
                    address: accountAddress,
                    ownerProgram: nil,
                    lamports: nil,
                    dataBase64: accountDataBase64.isEmpty ? nil : accountDataBase64,
                    idlAccount: idlAccount,
                    idl: parsedIDL
                )
            )
            DeveloperWorkstationKeyValueRow(key: "Status", value: result.status.title)
            DeveloperWorkstationKeyValueRow(key: "Data length", value: "\(result.dataLength) bytes")
            DeveloperWorkstationKeyValueRow(key: "Raw preview", value: result.rawPreview.isEmpty ? "Unavailable" : result.rawPreview)
            if let idlAccount {
                DeveloperWorkstationKeyValueRow(key: "Selected account type", value: idlAccount.name)
                DeveloperWorkstationKeyValueRow(key: "Discriminator", value: idlAccount.discriminatorHex)
            } else {
                DeveloperWorkstationKeyValueRow(key: "Selected account type", value: accountDecoderIDLAccountSelection == "__auto" ? "Auto discriminator match" : "Unavailable")
            }
            ForEach(result.fields) { field in
                DeveloperWorkstationKeyValueRow(key: field.name, value: "\(field.value) (\(field.type))")
            }
            Text(result.message)
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
        }
    }

    private func selectedAccountDecoderIDLAccount() -> WorkstationIDLAccount? {
        guard accountDecoderIDLAccountSelection != "__auto" else {
            return nil
        }
        return parsedIDL?.accounts.first { $0.name == accountDecoderIDLAccountSelection }
    }
}
