// import cert from "../../../../../../certs/lhv-sandbox-cert.crt";

import { fetchProxy } from "../../../fetchProxy.ts";

const mockData = {
  psuId: "donaldduck",
  psuCorporateId: "duckinc",
  xRequestId: "123e4567-e89b-12d3-a456-426614174000",
  tppRedirectUri: "",
  tppId: "PSDEE-LHVTEST-5d8bb6",
};

export class LHVTokenStrategy {
  baseUrl: string = "https://api.sandbox.lhv.eu/psd2";
  agent: null | Deno.HttpClient = null;
  authorisationCode: string = "";
  token: string = "";
  accessToken: string = "";
  refreshToken: string = "";
  authorisationId: string = "";
  scaStatus: string = "";

  constructor() {}

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

  async createAuthorization(): Promise<string | void> {
    const url = `${this.baseUrl}/v1/oauth/authorisations`;

    try {
      const response = await fetchProxy({
        url: url,
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "PSU-ID": mockData.psuId,
          "X-Request-ID": mockData.xRequestId,
        },
        body: {
          authenticationMethodId: "SID",
        },
      });

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }

      const responseData = await response.json();

      console.log("Response data:", responseData["authorisationId"]);

      this.authorisationId = responseData["authorisationId"];
      return this.authorisationId;
    } catch (error) {
      console.error("Error during authorization:", error);
    }
  }

  async getAuthorisationCode(): Promise<Record<string, string>> {
    if (!this.authorisationId) {
      throw new Error("No authorization ID. Call createAuthorization first.");
    }

    const url = `${this.baseUrl}/v1/oauth/authorisations/${this.authorisationId}`;

    try {
      const response = await fetchProxy({
        url,
        method: "GET",
        headers: {
          "Content-Type": "application/json",
          "PSU-ID": mockData.psuId,
          "X-Request-ID": mockData.xRequestId,
        },
      });

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }

      const responseData = await response.json();
      console.log("Response data:", responseData);

      this.authorisationCode = responseData["authorisationCode"];
      this.scaStatus = responseData["scaStatus"];

      return {
        authorisationCode: this.authorisationCode,
        scaStatus: this.scaStatus,
      };
    } catch (error) {
      console.error("Error fetching authorisation code:", error);
      throw error;
    }
  }

  async getTokenFromAuthorisationCode(): Promise<string> {
    if (!this.authorisationCode) {
      throw new Error(
        "No authorization code. Call getAuthorisationCode first."
      );
    }

    const url = `${this.baseUrl}/oauth/token`;

    console.log("Using authorisation code:", this.authorisationCode);

    try {
      const params = new URLSearchParams({
        grant_type: "authorization_code",
        code: this.authorisationCode,
        client_id: mockData.tppId,
      });

      const response = await fetchProxy({
        url,
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "X-Request-ID": mockData.xRequestId,
        },
        body: params.toString(),
      });

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }

      const responseData = await response.json();
      console.log("Response data:", responseData);

      this.accessToken = responseData["access_token"];
      this.token = this.accessToken;

      return this.accessToken;
    } catch (error) {
      console.error("Error fetching token:", error);
      throw error;
    }
  }
}
