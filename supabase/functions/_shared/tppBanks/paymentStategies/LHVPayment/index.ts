import axios from "https://esm.sh/axios@1.5.0";

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
  consentId: string = "";
  paymentId: string = "";
  authorisationId: string = "";

  constructor(token: string, consentId: string, accountIban?: string) {
    if (accountIban) {
      this.accountIban = accountIban;
    }

    this.consentId = consentId;
    this.token = token;

    const cert = Deno.readFileSync(
      "../../../../../certs/lhv-sandbox-certificate.crt"
    );
    const key = Deno.readFileSync("../../../../../certs/lhv-sandbox-key.key");
    this.agent = Deno.createHttpClient({
      cert: cert as unknown as string,
      key: key as unknown as string,
    });
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
    creditorAccount: string,
    creditorName: string,
    description: string,
    reference: string
  ): Promise<string | void> {
    const url = `${this.baseUrl}/v1/accounts`;

    const today = Temporal.Now.plainDateISO();
    const formattedToday = today.toString().replace(/-/g, "/");

    const requestBody = {
      debtorAccount: {
        iban: this.accountIban,
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
      remittanceInformationStructured: {
        reference: reference,
      },
      requestedExecutionDate: formattedToday,
    };

    try {
      const response = await axios.post(url, requestBody, {
        headers: {
          "Content-Type": "application/json",
          "Consent-ID": this.consentId,
          "X-Request-ID": mockData.xRequestId,
          Authorization: `Bearer ${this.token}`,
          "TPP-Redirect-Preferred": false,
          "PSU-IP-Address": mockData.psuIpAddress,
          PSU_Corporate_ID: mockData.psuCorporateId,
        },

        httpsAgent: this.agent,
      });

      console.log("Response status:", response.status);
      console.log("Response data:", response.data);

      this.paymentId = response.data["paymentId"];

      return response.data;
    } catch (error) {
      console.error("Error during authorization:", error);
    }
  }

  async authoriseSepaTransfer(): Promise<string | void> {
    const url = `${this.baseUrl}/v1/accounts?paymentId=${this.paymentId}`;

    const requestBody = {
      authenticationMethodId: "SID",
    };

    try {
      const response = await axios.post(url, requestBody, {
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${this.token}`,
          "PSU-IP-Address": mockData.psuIpAddress,
        },

        httpsAgent: this.agent,
      });

      console.log("Response status:", response.status);
      console.log("Response data:", response.data);

      this.authorisationId = response.data["authorisationId"];

      return response.data;
    } catch (error) {
      console.error("Error during authorization:", error);
    }
  }

  async getAuthorisationStatusForSepaTransfer(): Promise<string | void> {
    const url = `${this.baseUrl}/v1/accounts?paymentId=${this.paymentId}/authorisations/${this.authorisationId}`;

    try {
      const response = await axios.get(url, {
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${this.token}`,
          "PSU-IP-Address": mockData.psuIpAddress,
          "X-Request-ID": mockData.xRequestId,
        },

        httpsAgent: this.agent,
      });

      console.log("Response status:", response.status);
      console.log("Response data:", response.data);

      return response.data;
    } catch (error) {
      console.error("Error during authorization:", error);
    }
  }
}
