import { LHVTokenStrategy } from "./LHVToken/index.ts";

const delay = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

export class Token {
  token: string = "";
  tokenClass = new LHVTokenStrategy();

  constructor() {}

  async getLHVToken() {
    await this.tokenClass.execute(
      async () => await this.tokenClass.createAuthorization()
    );
    await delay(5000);

    await this.tokenClass.execute(
      async () => await this.tokenClass.getAuthorisationCode()
    );
    const result = await this.tokenClass.execute(
      async () => await this.tokenClass.getTokenFromAuthorisationCode()
    );

    if (typeof result === "string") {
      this.token = result;
    } else {
      throw new Error("Failed to retrieve token: result is not a string");
    }
  }

  public async createToken(bankName: "LHV" | "SEB"): Promise<void> {
    if (bankName === "LHV") {
      console.log("Creating LHV token");
      await this.getLHVToken();
    } else {
      throw new Error("Bank not supported");
    }
  }

  public getToken(): string {
    return this.token;
  }
}
