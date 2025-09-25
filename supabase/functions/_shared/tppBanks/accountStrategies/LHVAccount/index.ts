import * as fs from 'node:fs';
import axios from "https://esm.sh/axios@1.5.0";

const mockData = {
  psuId: "donaldduck",
  psuCorporateId: "duckinc",
  xRequestId: "123e4567-e89b-12d3-a456-426614174000",
  tppRedirectUri: "https://example.com/redirect",
  tppId: "PSDEE-LHVTEST-5d8bb6"
};

export class LHVAccountStrategy {
  baseUrl: string = "https://api.sandbox.lhv.eu/psd2";
  agent: null | Deno.HttpClient = null;
  token: string;
  consentId: string = "";
  authorisationId: string = "";
  accounts: any;
  static instance: LHVAccountStrategy;

  constructor(token: string, consentId: string) {


    this.consentId = consentId;
    this.token = token;

    const cert = fs.readFileSync("../../../../../certs/lhv-sandbox-cert.crt");
    const key = fs.readFileSync("../../../../../certs/lhv-sandbox-private-key.key");

    this.agent =  Deno.createHttpClient({
      cert: cert as unknown as string,
      key: key as unknown as string,
    });
  }

  static getInstance(token: string, consentId: string,): LHVAccountStrategy {
    if (!this.instance) {
      this.instance = new LHVAccountStrategy(token, consentId);  
    }
    return this.instance;
  }

  initialize(): void {
    console.log("Initializing Consent with baseUrl:", this.baseUrl);
  }

  async execute<T = void, P extends any[] = []>(
    action: (...args: P) => Promise<T>, 
    ...args: P
  ): Promise<T> {
    console.log(`Executing ${this.constructor.name} logic for:`, action.name || 'anonymous function');
    
    try {
      const result = await action(...args);
      console.log(`Successfully executed ${action.name || 'action'}`);
      return result;
    } catch (error) {
      console.error(`Error executing ${action.name || 'action'}:`, error);
      throw error;
    }
  }

  async getAccounts(): Promise<[] | void> {
    const url = `${this.baseUrl}/v1/accounts`;

    try {
      const response = await axios.get(
        url,
        {
          headers: {
            "Content-Type": "application/json",
            "Consent-ID": this.consentId,
            "X-Request-ID": mockData.xRequestId,
            "Authorization": `Bearer ${this.token}`,
          },

          httpsAgent: this.agent,
        }
      );

      console.log("Response status:", response.status);
      console.log("Response data:", response.data);

      this.accounts = response.data["accounts"];

      return response.data["accounts"];
    } catch (error) {
      console.error("Error during authorization:", error);
    }
  }


}
