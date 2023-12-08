import { ResponseModel } from "./ResponseModel.ts";

export const confirmedRequiredParams = (listOfParams: string[]): boolean => {
  for (const param of listOfParams) {
    if (param === undefined) {
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
