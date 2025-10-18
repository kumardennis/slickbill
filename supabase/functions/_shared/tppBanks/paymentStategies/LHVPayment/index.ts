import { fetchProxy } from "../../../fetchProxy.ts";

const mockData = {
  psuId: "donaldduck",
  psuIpAddress: "192.168.1.28",
  psuCorporateId: "duckinc",
  xRequestId: "123e4567-e89b-12d3-a456-426614174000",
  tppRedirectUri: "https://example.com/redirect",
  tppId: "PSDEE-LHVTEST-5d8bb6",
};

export class LHVPaymentStrategy {
  baseUrl: string = "https://api.sandbox.lhv.eu/psd2";
  agent: null | Deno.HttpClient = null;
  token: string;
  accountIban: string = "EE857700771001735904";
  paymentId: string = "";
  authorisationId: string = "";

  constructor(token: string) {
    this.token = token;
  }

  initialize(): void {
    console.log("Initializing Payment with baseUrl:", this.baseUrl);
  }

  async execute<T = void, P extends any[] = []>(
    action: (...args: P) => Promise<T>,
    ...args: P
  ): Promise<T> {
    console.log(
      `Executing ${this.constructor.name} logic for:`,
      action.name || "anonymous function"
    );

    try {
      const result = await action(...args);
      console.log(`Successfully executed ${action.name || "action"}`);
      return result;
    } catch (error) {
      console.error(`Error executing ${action.name || "action"}:`, error);
      throw error;
    }
  }

  async createSepaTransfer(
    amount: number,
    accountIban: string,
    creditorAccount: string,
    creditorName: string,
    description: string,
    reference: string
  ): Promise<string | void> {
    const url = `${this.baseUrl}/v1.1/payments/sepa-credit-transfers`;

    const today = Temporal.Now.plainDateISO();
    const formattedToday = today.toString().replace(/-/g, "-");

    const requestBody = {
      debtorAccount: {
        iban: accountIban,
      },
      instructedAmount: {
        currency: "EUR",
        amount: amount,
      },
      creditorAccount: {
        iban: creditorAccount,
      },
      creditorName: creditorName,
      remittanceInformationUnstructured: description,
      // remittanceInformationStructured: {
      //   reference: reference,
      // },
      requestedExecutionDate: formattedToday,
    };

    try {
      const response = await fetchProxy({
        url: url,
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-Request-ID": mockData.xRequestId,
          Authorization: `Bearer ${this.token}`,
          "TPP-Redirect-Preferred": "false",
          "PSU-IP-Address": mockData.psuIpAddress,
        },
        body: requestBody,
      });

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }

      const responseData = await response.json();

      console.log("Response data:", responseData);

      this.paymentId = responseData["paymentId"];

      return responseData;
    } catch (error) {
      console.error("Error during createSepaTransfer:", error);
    }
  }

  async authoriseSepaTransfer(): Promise<string | void> {
    const url = `${this.baseUrl}/v1/payments/sepa-credit-transfers/${this.paymentId}/authorisations`;

    const requestBody = {
      authenticationMethodId: "SID",
    };

    try {
      const response = await fetchProxy({
        url: url,
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${this.token}`,
          "PSU-IP-Address": mockData.psuIpAddress,
          "X-Request-ID": mockData.xRequestId,
        },
        body: requestBody,
      });

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }

      const responseData = await response.json();

      console.log("Response data:", responseData);

      this.authorisationId = responseData["authorisationId"];

      return responseData;
    } catch (error) {
      console.error("Error during authoriseSepaTransfer:", error);
    }
  }

  async getAuthorisationStatusForSepaTransfer(): Promise<string | void> {
    const url = `${this.baseUrl}/v1/payments/sepa-credit-transfers/${this.paymentId}/authorisations/${this.authorisationId}`;

    try {
      const response = await fetchProxy({
        url: url,
        method: "GET",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${this.token}`,
          "PSU-IP-Address": mockData.psuIpAddress,
          "X-Request-ID": mockData.xRequestId,
        },
      });

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }

      const responseData = await response.json();

      console.log("Response data:", responseData);

      return responseData;
    } catch (error) {
      console.error(
        "Error during getAuthorisationStatusForSepaTransfer:",
        error
      );
    }
  }
}
