import { LHVConsentStrategy } from "./LHVConsent/index.ts";

export class Consent {
  private bankName: "LHV" | "SEB" = "LHV";
  token: string = "";
  consentId: string = "";

  constructor() {}

  async getLHVConsent() {
    const consent = new LHVConsentStrategy(this.token);

    await consent.execute(async () => await consent.createConsent());
    await consent.execute(async () => await consent.getAuthorisationId());
    const result = await consent.execute(
      async () => await consent.getConsent()
    );

    if (result && "consentId" in result) {
      this.consentId = result.consentId;
    } else if (typeof result === "string") {
      throw new Error(
        "Failed to retrieve token: result is a string, not an object with consentId"
      );
    } else {
      throw new Error(
        "Failed to retrieve token: result is undefined or invalid"
      );
    }
  }

  public async createConsent(
    bankName: "LHV" | "SEB",
    token: string
  ): Promise<void> {
    this.token = token;
    if (bankName === "LHV") {
      await this.getLHVConsent();
      return;
    }

    throw new Error("Bank not supported");
  }

  public getConsentId(): string {
    return this.consentId;
  }
}
