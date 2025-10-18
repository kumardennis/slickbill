import { LHVPaymentStrategy } from "./LHVPayment/index.ts";

export class Payment {
  private bankName: "LHV" | "SEB" = "LHV";
  token: string = "";
  accountIban: string = "";
  sepaTransferData: any = {};

  constructor(bankName: "LHV" | "SEB", token: string) {
    this.bankName = bankName;
    this.token = token;
  }

  async createLHVPayment(
    amount: number,
    accountIban: string,
    creditorAccount: string,
    creditorName: string,
    description: string,
    reference: string
  ) {
    const payment = new LHVPaymentStrategy(this.token);

    await payment.execute(
      async () =>
        await payment.createSepaTransfer(
          amount,
          accountIban,
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
    amount: number,
    accountIban: string,
    creditorAccount: string,
    creditorName: string,
    description: string,
    reference: string
  ): Promise<void> {
    if (this.bankName === "LHV") {
      await this.createLHVPayment(
        amount,
        accountIban,
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
