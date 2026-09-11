import { ResponseModel } from "./ResponseModel.ts";

export const confirmedRequiredParams = (listOfParams: unknown[]): boolean => {
  for (const param of listOfParams) {
    if (param === undefined || param === null) {
      return false;
    }
    if (typeof param === "string") {
      const trimmed = param.trim();
      if (trimmed.length === 0 || trimmed.toLowerCase() === "null") {
        return false;
      }
    }
    if (typeof param === "number" && !Number.isFinite(param)) {
      return false;
    }
  }

  return true;
};

export const errorResponseData: ResponseModel = {
  isRequestSuccessful: false,
  data: null,
  error: "Some values were not correct or are missing...",
};
