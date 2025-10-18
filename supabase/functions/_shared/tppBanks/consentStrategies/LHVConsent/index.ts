import { fetchProxy } from "../../../fetchProxy.ts";

const mockData = {
  psuId: "donaldduck",
  psuCorporateId: "duckinc",
  xRequestId: "123e4567-e89b-12d3-a456-426614174000",
  tppRedirectUri: "https://example.com/redirect",
  tppId: "PSDEE-LHVTEST-5d8bb6",
};

export class LHVConsentStrategy {
  baseUrl: string = "https://api.sandbox.lhv.eu/psd2";
  agent: null | Deno.HttpClient = null;
  token: string | undefined;
  accountIban: string = "EE857700771001735904";
  consentId: string = "";
  authorisationId: string = "";

  constructor() {}

  initialize(): void {
    console.log("Initializing Consent with baseUrl:", this.baseUrl);
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

  async createConsent(
    token: string,
    accountIban?: string
  ): Promise<string | void> {
    const url = `${this.baseUrl}/v1/consents`;

    if (accountIban) {
      this.accountIban = accountIban;
    }

    this.token = token;

    const consentRequestBody = {
      access: {
        balances: [
          {
            iban: this.accountIban,
          },
        ],
        transactions: [
          {
            iban: this.accountIban,
          },
        ],
        availableAccounts: "allAccounts",
      },
      recurringIndicator: true,
      validUntil: "2025-11-01",
      frequencyPerDay: 50,
      combinedServiceIndicator: false,
    };

    try {
      const response = await fetchProxy({
        url: url,
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          PSU_ID: mockData.psuId,
          "X-Request-ID": mockData.xRequestId,
          "TPP-Redirect-URI": mockData.tppRedirectUri,
          Authorization: `Bearer ${this.token}`,
        },
        body: consentRequestBody,
      });

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }
      const responseData = await response.json();
      console.log("Response data:", responseData);

      this.consentId = responseData["consentId"];

      return responseData["consentId"];
    } catch (error) {
      console.error("Error during authorization:", error);
    }
  }

  async getAuthorisationId(): Promise<Record<string, string> | void> {
    const url = `${this.baseUrl}/v1/oauth/consent/${this.consentId}/authorisations`;

    try {
      const response = await fetchProxy({
        url: url,
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-Request-ID": mockData.xRequestId,
          Authorization: `Bearer ${this.token}`,
        },
        body: {
          authenticationMethodId: "SID",
        },
      });

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }
      const responseData = await response.json();

      this.authorisationId = responseData["authorisationId"];

      return {
        authorisationId: responseData["authorisationId"],
        scaStatus: responseData["scaStatus"],
      };
    } catch (error) {
      console.error("Error fetching authorisation code:", error);
    }
  }

  async getConsent(): Promise<Record<string, string> | void> {
    const url = `${this.baseUrl}/v1/oauth/consent/${this.consentId}/authorisations/${this.authorisationId}`;

    try {
      const response = await fetchProxy({
        url: url,
        method: "GET",
        headers: {
          "Content-Type": "application/json",
          "X-Request-ID": mockData.xRequestId,
          Authorization: `Bearer ${this.token}`,
        },
      });

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }
      const responseData = await response.json();

      return {
        scaStatus: responseData["scaStatus"],
        consentId: this.consentId,
      };
    } catch (error) {
      console.error("Error fetching authorisation code:", error);
    }
  }
}
