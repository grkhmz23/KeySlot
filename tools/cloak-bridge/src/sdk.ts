import {
  calculateFeeQuote,
  CLOAK_PROGRAM_ID,
  NEXT_EXECUTION_GATES,
  NATIVE_SOL_MINT,
  type CloakFeeValidation,
  type CloakFeeValidationSample,
  type CloakSdkValidation,
} from "./contracts.ts";

const FEE_SAMPLE_AMOUNTS = ["10000000", "50000000", "1000000000"] as const;

type CloakSdkModule = {
  CLOAK_PROGRAM_ID?: unknown;
  NATIVE_SOL_MINT?: unknown;
  VERSION?: unknown;
  calculateSolFeeLamports?: unknown;
  calculateSolNetAmountLamports?: unknown;
  calculateFeeBigint?: unknown;
};

export async function loadSdkValidation(): Promise<CloakSdkValidation> {
  const sdk = await importCloakSdk();
  if (!sdk) {
    return {
      sdkInstalled: false,
      sdkImportOk: false,
      expectedProgramId: CLOAK_PROGRAM_ID,
      programIdMatches: false,
      feeHelpersAvailable: false,
    };
  }

  const programId = publicKeyString(sdk.CLOAK_PROGRAM_ID);
  const nativeSolMint = publicKeyString(sdk.NATIVE_SOL_MINT);
  return {
    sdkInstalled: true,
    sdkImportOk: true,
    sdkVersion: typeof sdk.VERSION === "string" ? sdk.VERSION : undefined,
    cloakProgramId: programId,
    expectedProgramId: CLOAK_PROGRAM_ID,
    programIdMatches: programId === CLOAK_PROGRAM_ID,
    nativeSolMint,
    feeHelpersAvailable: hasFeeHelpers(sdk),
  };
}

export async function loadFeeValidation(): Promise<CloakFeeValidation> {
  const sdk = await importCloakSdk();
  if (!sdk || !hasFeeHelpers(sdk)) {
    return {
      available: false,
      source: "gorkh-local",
      samples: FEE_SAMPLE_AMOUNTS.map((grossLamports) => localFeeSample(grossLamports)),
      message: "Cloak SDK fee helpers are unavailable. GORKH local integer fee model remains active.",
    };
  }

  const samples = FEE_SAMPLE_AMOUNTS.map((grossLamports) => {
    const local = calculateFeeQuote(grossLamports);
    const sdkFee = sdkFeeLamports(sdk, grossLamports);
    const sdkNet = sdkNetLamports(sdk, grossLamports, sdkFee);
    return {
      grossLamports,
      gorkhFeeLamports: local.totalFeeLamports,
      gorkhNetLamports: local.netLamports,
      sdkFeeLamports: sdkFee,
      sdkNetLamports: sdkNet,
      matches: sdkFee === local.totalFeeLamports && sdkNet === local.netLamports,
    };
  });

  return {
    available: true,
    source: "sdk",
    samples,
    message: samples.every((sample) => sample.matches)
      ? "Cloak SDK SOL fee helpers match the GORKH local model for sample values."
      : "Cloak SDK SOL fee helpers differ from the GORKH local model for at least one sample.",
  };
}

export function nextRequiredGates(): string[] {
  return [...NEXT_EXECUTION_GATES];
}

async function importCloakSdk(): Promise<CloakSdkModule | undefined> {
  try {
    return await import("@cloak.dev/sdk") as CloakSdkModule;
  } catch {
    return undefined;
  }
}

function hasFeeHelpers(sdk: CloakSdkModule): boolean {
  return typeof sdk.calculateSolFeeLamports === "function"
    || typeof sdk.calculateFeeBigint === "function";
}

function publicKeyString(value: unknown): string | undefined {
  if (typeof value === "string") {
    return value;
  }
  if (value && typeof value === "object" && "toBase58" in value && typeof value.toBase58 === "function") {
    return value.toBase58();
  }
  if (value && typeof value === "object" && "toString" in value && typeof value.toString === "function") {
    return value.toString();
  }
  return undefined;
}

function toLamportsString(value: unknown): string {
  if (typeof value === "bigint") {
    return value.toString();
  }
  if (typeof value === "number" && Number.isSafeInteger(value) && value >= 0) {
    return String(value);
  }
  if (typeof value === "string" && /^[0-9]+$/.test(value)) {
    return value;
  }
  throw new Error("SDK fee helper returned a non-integer lamport value.");
}

function sdkFeeLamports(sdk: CloakSdkModule, grossLamports: string): string {
  if (typeof sdk.calculateSolFeeLamports === "function") {
    return toLamportsString((sdk.calculateSolFeeLamports as (gross: bigint) => unknown)(BigInt(grossLamports)));
  }
  if (typeof sdk.calculateFeeBigint === "function") {
    return toLamportsString((sdk.calculateFeeBigint as (gross: bigint) => unknown)(BigInt(grossLamports)));
  }
  throw new Error("Cloak SDK fee helper unavailable.");
}

function sdkNetLamports(sdk: CloakSdkModule, grossLamports: string, sdkFee: string): string {
  if (typeof sdk.calculateSolNetAmountLamports === "function") {
    return toLamportsString((sdk.calculateSolNetAmountLamports as (gross: bigint) => unknown)(BigInt(grossLamports)));
  }
  return (BigInt(grossLamports) - BigInt(sdkFee)).toString();
}

function localFeeSample(grossLamports: string): CloakFeeValidationSample {
  const local = calculateFeeQuote(grossLamports);
  return {
    grossLamports,
    gorkhFeeLamports: local.totalFeeLamports,
    gorkhNetLamports: local.netLamports,
  };
}
