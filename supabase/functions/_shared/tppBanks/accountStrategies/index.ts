import { LHVAccountStrategy } from "./LHVAccount/index.ts";

export class Consent {
  private bankName: "LHV" | "SEB" = "LHV";
  token: string = "";
  consentId: string = "";
  accounts: [] = [];

  constructor() {}

  async getLHVAccounts() {
    const account = LHVAccountStrategy.getInstance(this.token, this.consentId);

    const result = await account.execute(
      async () => await account.getAccounts()
    );

    if (result) {
      this.accounts = result;
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

  public async getAccounts(
    bankName: "LHV" | "SEB",
    token: string,
    consentId: string
  ): Promise<void> {
    this.token = token;
    this.consentId = consentId;
    if (bankName === "LHV") {
      await this.getLHVAccounts();
      return;
    }

    throw new Error("Bank not supported");
  }

  public getAccountList(): [] {
    return this.accounts;
  }
}
