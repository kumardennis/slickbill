export const getParentOrigin = (): string => {
  // When inside an iframe, referrer is usually the parent URL.
  try {
    const ref = document.referrer;
    if (ref) return new URL(ref).origin;
  } catch {
    // ignore
  }
  // Fallback (testing only). Prefer not to rely on "*", but better than crashing.
  return "*";
};
