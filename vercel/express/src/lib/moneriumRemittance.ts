/**
 * Monerium maps `referenceNumber` onto the SEPA RF Creditor Reference
 * (ISO 11649). If both memo and referenceNumber are set, referenceNumber
 * wins and memo is ignored on the bank transfer.
 *
 * Invented ids like `wd1789…` / `sb123` are not RF references. Estonian
 * banks then reject the payment: "Reference number missing or does not
 * meet beneficiary specified format."
 */

export function isIso11649RfReference(value: string): boolean {
  const compact = value.replace(/\s+/g, "").toUpperCase();
  if (!/^RF[0-9]{2}[A-Z0-9]{1,21}$/.test(compact)) return false;

  const rearranged = compact.slice(4) + compact.slice(0, 4);
  let digits = "";
  for (const ch of rearranged) {
    digits += /[A-Z]/.test(ch) ? String(ch.charCodeAt(0) - 55) : ch;
  }

  let remainder = 0;
  for (const ch of digits) {
    remainder = (remainder * 10 + Number(ch)) % 97;
  }
  return remainder === 1;
}

/** Drop anything that is not a valid RF creditor reference. */
export function stripInvalidMoneriumReference(
  order: Record<string, unknown>,
): void {
  const raw =
    typeof order.referenceNumber === "string"
      ? order.referenceNumber.trim()
      : "";
  if (!raw || !isIso11649RfReference(raw)) {
    delete order.referenceNumber;
    return;
  }
  order.referenceNumber = raw.replace(/\s+/g, "").toUpperCase().slice(0, 35);
}
