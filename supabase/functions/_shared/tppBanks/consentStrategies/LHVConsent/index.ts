import axios from "https://esm.sh/axios@1.5.0";

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
  token: string;
  accountIban: string = "EE857700771001735904";
  consentId: string = "";
  authorisationId: string = "";

  constructor(token: string, accountIban?: string) {
    if (accountIban) {
      this.accountIban = accountIban;
    }

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

  async createConsent(): Promise<string | void> {
    const url = `${this.baseUrl}/v1/consents`;

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
      const response = await axios.post(url, consentRequestBody, {
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          PSU_ID: mockData.psuId,
          "X-Request-ID": mockData.xRequestId,
          "TPP-Redirect-URI": mockData.tppRedirectUri,
          Authorization: `Bearer ${this.token}`,
        },

        httpsAgent: this.agent,
      });

      console.log("Response status:", response.status);
      console.log("Response data:", response.data);

      this.consentId = response.data["consentId"];

      return response.data["consentId"];
    } catch (error) {
      console.error("Error during authorization:", error);
    }
  }

  async getAuthorisationId(): Promise<Record<string, string> | void> {
    const url = `${this.baseUrl}/v1/oauth/consent/${this.consentId}/authorisations`;

    try {
      const response = await axios.post(
        url,
        {
          authenticationMethodId: "SID",
        },
        {
          headers: {
            "Content-Type": "application/json",
            "X-Request-ID": mockData.xRequestId,
          },
          httpsAgent: this.agent,
        }
      );

      console.log("Response status:", response.status);
      console.log("Response data:", response.data);

      this.authorisationId = response.data["authorisationId"];

      return {
        authorisationId: response.data["authorisationId"],
        scaStatus: response.data["scaStatus"],
      };
    } catch (error) {
      console.error("Error fetching authorisation code:", error);
    }
  }

  async getConsent(): Promise<Record<string, string> | void> {
    const url = `${this.baseUrl}/v1/oauth/consent/${this.consentId}/authorisations/${this.authorisationId}`;

    try {
      const response = await axios.get(url, {
        headers: {
          "Content-Type": "application/json",
          "X-Request-ID": mockData.xRequestId,
        },
        httpsAgent: this.agent,
      });

      console.log("Response status:", response.status);
      console.log("Response data:", response.data);

      this.authorisationId = response.data["authorisationId"];

      return {
        scaStatus: response.data["scaStatus"],
        consentId: this.consentId,
      };
    } catch (error) {
      console.error("Error fetching authorisation code:", error);
    }
  }
}
