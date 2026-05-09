import Foundation

struct RaydiumReadOnlyAdapter: LPPositionAdapter {
    let protocolKind: LPProtocolKind = .raydium
    let client: any RaydiumAPIClienting

    init(client: any RaydiumAPIClienting = RaydiumAPIClient()) {
        self.client = client
    }

    func fetchPositions(
        profiles: [WalletProfile],
        network: WalletNetwork,
        prices: [String: PortfolioPriceQuote]
    ) async -> LPAdapterResult {
        let updatedAt = Date()
        var records: [(RaydiumPositionRecord, WalletProfile)] = []
        var messages: [String] = []
        var sawEmpty = false
        var sawError = false

        for profile in profiles {
            do {
                let stake = try await client.fetchOwnerStakePositions(owner: profile.publicAddress, network: network)
                append(stake, profile: profile, records: &records, messages: &messages, sawEmpty: &sawEmpty)
            } catch {
                sawError = true
                messages.append("\(profile.label): \(safeMessage(error.localizedDescription))")
            }

            do {
                let locked = try await client.fetchOwnerCLMMLockPositions(owner: profile.publicAddress, network: network)
                append(locked, profile: profile, records: &records, messages: &messages, sawEmpty: &sawEmpty)
            } catch {
                sawError = true
                messages.append("\(profile.label): \(safeMessage(error.localizedDescription))")
            }
        }

        if records.isEmpty {
            if sawError {
                return LPAdapterResult(
                    protocolKind: protocolKind,
                    status: .error,
                    positions: [],
                    source: .publicAPI,
                    updatedAt: updatedAt,
                    errorMessage: messages.joined(separator: " ")
                )
            }
            return LPAdapterResult(
                protocolKind: protocolKind,
                status: sawEmpty ? .empty : .unavailable,
                positions: [],
                source: sawEmpty ? .publicAPI : .unavailable,
                updatedAt: updatedAt,
                errorMessage: sawEmpty ? "No Raydium Owner API LP positions returned for this wallet scope." : "Raydium Owner API did not return a usable read-only state."
            )
        }

        let enrichment = await enrich(records: records.map(\.0), network: network)
        if let reason = enrichment.unavailableReason {
            messages.append(reason)
        }

        let positions = records.map { record, profile in
            normalize(
                record: record,
                profile: profile,
                network: network,
                portfolioPrices: prices,
                enrichment: enrichment,
                updatedAt: updatedAt
            )
        }
        let hasPartial = positions.contains { $0.status == .partial } || enrichment.unavailableReason != nil || sawError
        let status: LPAdapterStatus = hasPartial ? .partial : .loaded
        let breakdown = poolTypeBreakdown(records.map(\.0))
        if !breakdown.isEmpty {
            messages.append("Raydium pool types: \(breakdown).")
        }

        return LPAdapterResult(
            protocolKind: protocolKind,
            status: status,
            positions: positions,
            source: .publicAPI,
            updatedAt: updatedAt,
            errorMessage: messages.isEmpty ? nil : messages.joined(separator: " ")
        )
    }

    private func append(
        _ result: RaydiumOwnerEndpointResult,
        profile: WalletProfile,
        records: inout [(RaydiumPositionRecord, WalletProfile)],
        messages: inout [String],
        sawEmpty: inout Bool
    ) {
        switch result.status {
        case .loaded, .partial, .stale:
            records.append(contentsOf: result.positions.map { ($0, profile) })
            if let message = result.message, !message.isEmpty {
                messages.append("\(profile.label): \(safeMessage(message))")
            }
        case .empty:
            sawEmpty = true
        case .unavailable, .error, .idle:
            if let message = result.message, !message.isEmpty {
                messages.append("\(profile.label): \(safeMessage(message))")
            }
        }
    }

    private func enrich(records: [RaydiumPositionRecord], network: WalletNetwork) async -> RaydiumEnrichment {
        let poolIDs = records.compactMap(\.poolAddress)
        var mintIDs = Set(records.flatMap { [$0.lpMintAddress, $0.tokenAMint, $0.tokenBMint].compactMap { $0 } })
        var messages: [String] = []

        var pools: [String: RaydiumPoolInfo] = [:]
        do {
            pools = try await client.fetchPoolInfos(ids: poolIDs, network: network)
            pools.values.forEach { pool in
                [pool.lpMintAddress, pool.tokenAMint, pool.tokenBMint].compactMap { $0 }.forEach { mintIDs.insert($0) }
            }
        } catch where poolIDs.isEmpty {
        } catch {
            messages.append("Pool enrichment unavailable: \(safeMessage(error.localizedDescription))")
        }

        var mints: [String: RaydiumMintInfo] = [:]
        do {
            mints = try await client.fetchMintInfos(mints: Array(mintIDs), network: network)
        } catch where mintIDs.isEmpty {
        } catch {
            messages.append("Mint enrichment unavailable: \(safeMessage(error.localizedDescription))")
        }

        var raydiumPrices: [String: Decimal] = [:]
        do {
            raydiumPrices = try await client.fetchMintPrices(mints: Array(mintIDs), network: network)
        } catch where mintIDs.isEmpty {
        } catch {
            messages.append("Raydium price enrichment unavailable: \(safeMessage(error.localizedDescription))")
        }

        return RaydiumEnrichment(
            poolsByID: pools,
            mintsByID: mints,
            pricesByMint: raydiumPrices,
            unavailableReason: messages.isEmpty ? nil : messages.joined(separator: " ")
        )
    }

    private func normalize(
        record: RaydiumPositionRecord,
        profile: WalletProfile,
        network: WalletNetwork,
        portfolioPrices: [String: PortfolioPriceQuote],
        enrichment: RaydiumEnrichment,
        updatedAt: Date
    ) -> LPPositionSummary {
        let pool = record.poolAddress.flatMap { enrichment.poolsByID[$0] }
        let tokenAMint = record.tokenAMint ?? pool?.tokenAMint
        let tokenBMint = record.tokenBMint ?? pool?.tokenBMint
        let tokenA = asset(
            mint: tokenAMint,
            rawAmount: record.tokenAAmountRaw,
            uiAmount: record.tokenAAmountUI,
            portfolioPrices: portfolioPrices,
            raydiumPrices: enrichment.pricesByMint,
            mints: enrichment.mintsByID,
            network: network
        )
        let tokenB = asset(
            mint: tokenBMint,
            rawAmount: record.tokenBAmountRaw,
            uiAmount: record.tokenBAmountUI,
            portfolioPrices: portfolioPrices,
            raydiumPrices: enrichment.pricesByMint,
            mints: enrichment.mintsByID,
            network: network
        )
        let estimatedValue = totalValue(tokenA: tokenA, tokenB: tokenB) ?? pool?.tvlUSD
        let partialReasons = [
            record.partialReason,
            enrichment.unavailableReason,
            tokenA == nil || tokenB == nil ? "Raydium token amounts or mints are incomplete." : nil,
            estimatedValue == nil ? "Raydium USD value is unavailable." : nil
        ].compactMap { $0 }
        let status: LPAdapterStatus = partialReasons.isEmpty ? .loaded : .partial
        let metadata = metadataStatus(record: record, pool: pool, partialReasons: partialReasons)

        return LPPositionSummary(
            walletID: profile.id,
            walletLabel: profile.label,
            walletPublicAddress: profile.publicAddress,
            network: network,
            protocolKind: .raydium,
            poolAddress: record.poolAddress ?? "unknown-raydium-pool",
            positionAddress: record.positionAddress ?? record.lpMintAddress ?? "unknown-raydium-position",
            positionMintAddress: record.lpMintAddress,
            tokenA: tokenA,
            tokenB: tokenB,
            estimatedValueUSD: estimatedValue,
            feeSummary: feeSummary(record: record, tokenAMint: tokenAMint, tokenBMint: tokenBMint, portfolioPrices: portfolioPrices, raydiumPrices: enrichment.pricesByMint, mints: enrichment.mintsByID, network: network),
            rangeSummary: rangeSummary(record: record),
            impermanentLoss: .unavailable,
            source: .publicAPI,
            updatedAt: updatedAt,
            status: status,
            metadataStatus: metadata,
            errorMessage: partialReasons.isEmpty ? nil : partialReasons.joined(separator: " ")
        )
    }

    private func asset(
        mint: String?,
        rawAmount: String?,
        uiAmount: String?,
        portfolioPrices: [String: PortfolioPriceQuote],
        raydiumPrices: [String: Decimal],
        mints: [String: RaydiumMintInfo],
        network: WalletNetwork
    ) -> LPPositionAssetAmount? {
        guard let mint else {
            return nil
        }
        let registryMetadata = TokenMetadataRegistry.lookup(mintAddress: mint, network: network)
        let raydiumMetadata = mints[mint]
        let decimals = raydiumMetadata?.decimals ?? registryMetadata?.decimals
        let amount = decimal(uiAmount) ?? uiAmountFromRaw(rawAmount, decimals: decimals)
        let priceQuote = portfolioPrices[mint]
        let price = priceQuote?.usdPrice ?? raydiumPrices[mint]
        let value = amount.flatMap { amount in price.map { amount * $0 } }
        return LPPositionAssetAmount(
            mintAddress: mint,
            symbol: raydiumMetadata?.symbol ?? registryMetadata?.symbol ?? "UNKNOWN",
            name: raydiumMetadata?.name ?? registryMetadata?.name ?? "Unknown Token",
            amountRaw: uint64(rawAmount),
            decimals: decimals,
            uiAmountString: uiAmount ?? amount.map { NSDecimalNumber(decimal: $0).stringValue },
            usdValue: value,
            priceQuote: priceQuote,
            source: .publicAPI
        )
    }

    private func feeSummary(
        record: RaydiumPositionRecord,
        tokenAMint: String?,
        tokenBMint: String?,
        portfolioPrices: [String: PortfolioPriceQuote],
        raydiumPrices: [String: Decimal],
        mints: [String: RaydiumMintInfo],
        network: WalletNetwork
    ) -> LPFeeSummary {
        let tokenAFees = asset(
            mint: tokenAMint,
            rawAmount: record.feeAAmountRaw,
            uiAmount: record.feeAAmountUI,
            portfolioPrices: portfolioPrices,
            raydiumPrices: raydiumPrices,
            mints: mints,
            network: network
        )
        let tokenBFees = asset(
            mint: tokenBMint,
            rawAmount: record.feeBAmountRaw,
            uiAmount: record.feeBAmountUI,
            portfolioPrices: portfolioPrices,
            raydiumPrices: raydiumPrices,
            mints: mints,
            network: network
        )
        let values = [tokenAFees?.usdValue, tokenBFees?.usdValue].compactMap { $0 }
        return LPFeeSummary(
            tokenAFees: tokenAFees,
            tokenBFees: tokenBFees,
            totalUSD: values.isEmpty ? nil : values.reduce(Decimal(0), +),
            unavailableReason: tokenAFees == nil && tokenBFees == nil ? "Raydium fee amounts are unavailable or locked behind cached Owner API fields." : nil
        )
    }

    private func rangeSummary(record: RaydiumPositionRecord) -> LPRangeSummary {
        switch record.kind {
        case .lockedCLMM:
            let reason = record.lockEndTime.map { "Locked until \($0.formatted(date: .abbreviated, time: .shortened)). Full tick range is unavailable from the Owner API." }
                ?? "Locked CLMM range metadata is unavailable from the Owner API."
            return LPRangeSummary(
                lowerBinID: nil,
                upperBinID: nil,
                currentBinID: nil,
                state: .unknown,
                unavailableReason: reason
            )
        case .standardLP, .farm, .unknown:
            return .unavailable
        }
    }

    private func metadataStatus(record: RaydiumPositionRecord, pool: RaydiumPoolInfo?, partialReasons: [String]) -> String {
        var parts = [
            "\(record.kind.title)",
            record.sourceEndpoint,
            RaydiumConstants.cacheNotice
        ]
        if let poolType = pool?.poolType, poolType != .unknown {
            parts.append("Pool enrichment: \(poolType.title)")
        }
        if record.pendingRewardCount > 0 {
            parts.append("Pending reward entries: \(record.pendingRewardCount)")
        }
        if !partialReasons.isEmpty {
            parts.append("Partial: \(partialReasons.joined(separator: " "))")
        }
        return parts.joined(separator: " | ")
    }

    private func poolTypeBreakdown(_ records: [RaydiumPositionRecord]) -> String {
        let groups = Dictionary(grouping: records, by: \.kind)
        return groups
            .map { "\($0.key.title): \($0.value.count)" }
            .sorted()
            .joined(separator: ", ")
    }

    private func totalValue(tokenA: LPPositionAssetAmount?, tokenB: LPPositionAssetAmount?) -> Decimal? {
        let values = [tokenA?.usdValue, tokenB?.usdValue].compactMap { $0 }
        guard values.count == [tokenA, tokenB].compactMap({ $0 }).count, !values.isEmpty else {
            return nil
        }
        return values.reduce(Decimal(0), +)
    }

    private func uiAmountFromRaw(_ raw: String?, decimals: UInt8?) -> Decimal? {
        guard let rawDecimal = decimal(raw), let decimals else {
            return nil
        }
        return rawDecimal / pow10(Int(decimals))
    }

    private func pow10(_ value: Int) -> Decimal {
        guard value > 0 else {
            return 1
        }
        return (0..<value).reduce(Decimal(1)) { result, _ in result * 10 }
    }

    private func uint64(_ value: String?) -> UInt64? {
        guard let value else {
            return nil
        }
        return UInt64(value)
    }

    private func decimal(_ value: String?) -> Decimal? {
        guard let value else {
            return nil
        }
        return Decimal(string: value)
    }

    private func safeMessage(_ value: String) -> String {
        Redaction.containsSensitiveMaterial(value) ? "[redacted raydium adapter message]" : value
    }
}
