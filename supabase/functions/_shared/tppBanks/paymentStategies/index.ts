import { LHVPaymentStrategy } from "./LHVPayment/index.ts";

export class Consent {
  private bankName: "LHV" | "SEB" = "LHV";
  token: string = "";
  consentId: string = "";
  accountIban: string = "";
  sepaTransferData: any = {};

  constructor(
    bankName: "LHV" | "SEB",
    token: string,
    consentId: string,
    accountIban: string
  ) {
    this.bankName = bankName;
    this.token = token;
    this.consentId = consentId;
    this.accountIban = accountIban;
  }

  async createLHVPayment(
    amount: number,
    creditorAccount: string,
    creditorName: string,
    description: string,
    reference: string
  ) {
    const payment = LHVPaymentStrategy.getInstance(
      this.token,
      this.consentId,
      this.accountIban
    );

    await payment.execute(
      async () =>
        await payment.createSepaTransfer(
          amount,
          creditorAccount,
          creditorName,
          description,
          reference
        )
    );
    await payment.execute(async () => await payment.authoriseSepaTransfer());
    const result = await payment.execute(
      async () => await payment.getAuthorisationStatusForSepaTransfer()
    );

    if (result) {
      this.sepaTransferData = result;
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

  public async createPayment(
    bankName: "LHV" | "SEB",
    token: string,
    consentId: string,
    accountIban: string,
    amount: number,
    creditorAccount: string,
    creditorName: string,
    description: string,
    reference: string
  ): Promise<void> {
    this.token = token;
    this.consentId = consentId;
    this.accountIban = accountIban;
    if (bankName === "LHV") {
      await this.createLHVPayment(
        amount,
        creditorAccount,
        creditorName,
        description,
        reference
      );
      return;
    }

    throw new Error("Bank not supported");
  }

  public getPaymentData() {
    return this.sepaTransferData;
  }
}
