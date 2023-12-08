export const urlBase64ToBlob = (
  urlBase64: string,
  mimeType = "image/jpeg",
): any => {
  const base64 = urlBase64.replace("-", "+").replace("_", "/");
  return urlBase64ToBlob(base64, mimeType);
};
