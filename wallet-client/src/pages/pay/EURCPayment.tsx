import { useSearchParams } from "react-router-dom";
import { useCurrentUser, useSendUserOperation } from "@coinbase/cdp-hooks";
import { encodeFunctionData, parseUnits } from "viem";
import { useEffect, useMemo, useRef, useState } from "react";
import { toast } from "react-toastify";

const eurcContractAddress = "0x60a3E35Cc302bFA44Cb288Bc5a4F316Fdb1adb42"; // EURC on Base

export const EURCPayment = () => {
  const [searchParams] = useSearchParams();
  const { sendUserOperation } = useSendUserOperation();
  const { currentUser } = useCurrentUser();
  const smartAccount = currentUser?.evmSmartAccounts?.[0];
  const [isPending, setIsPending] = useState(false);
  const [txHash, setTxHash] = useState<string | null>(null);

  const to = searchParams.get("to") ?? "";
  const amount = searchParams.get("amount") ?? "";
  const description = searchParams.get("description") ?? "";
  const receiver = searchParams.get("receiver") ?? "";

  // Toasts on updates (UI-only)
  const prevRef = useRef({
    to: "",
    amount: "",
    receiver: "",
    description: "",
    smartAccount: "" as string | undefined,
    isPending: false,
    txHash: null as string | null,
  });

  useEffect(() => {
    const prev = prevRef.current;

    if (prev.smartAccount !== smartAccount) {
      if (smartAccount) toast.success("Wallet connected");
      else toast.info("Wallet not connected yet");
    }

    if ((prev.to !== to || prev.amount !== amount) && (to || amount)) {
      toast.info("Payment details updated");
    }

    if (
      (prev.receiver !== receiver || prev.description !== description) &&
      (receiver || description)
    ) {
      toast.info("Metadata updated");
    }

    if (!prev.isPending && isPending) {
      toast.info("Sending transaction…");
    }

    if (prev.txHash !== txHash && txHash) {
      toast.success("Transaction submitted");
    }

    prevRef.current = {
      to,
      amount,
      receiver,
      description,
      smartAccount,
      isPending,
      txHash,
    };
  }, [to, amount, receiver, description, smartAccount, isPending, txHash]);

  const { isValid, amountLabel, metaLabel } = useMemo(() => {
    const toTrimmed = to.trim();
    const amountTrimmed = amount.trim();

    const has0x = toTrimmed.startsWith("0x");

    const parsedAmount = Number(amountTrimmed);
    const amountOk =
      amountTrimmed.length > 0 &&
      Number.isFinite(parsedAmount) &&
      parsedAmount > 0;

    const isOk = has0x && amountOk;

    const amountDisplay = amountOk
      ? `${amountTrimmed} EURC`
      : amountTrimmed || "—";

    const metaParts = [
      receiver ? `Receiver: ${receiver}` : null,
      description ? `Note: ${description}` : null,
    ].filter(Boolean);

    return {
      isValid: isOk,
      amountLabel: amountDisplay,
      metaLabel: metaParts.length ? metaParts.join(" · ") : "",
    };
  }, [to, amount, description, receiver]);

  const handlePay = async () => {
    if (!smartAccount) {
      toast.error("Wallet not connected");
      return;
    }
    if (!isValid) {
      toast.error("Invalid payment parameters");
      return;
    }

    const data = encodeFunctionData({
      abi: [
        {
          name: "transfer",
          type: "function",
          inputs: [
            { name: "to", type: "address" },
            { name: "value", type: "uint256" },
          ],
          outputs: [{ type: "bool" }],
        },
      ],
      functionName: "transfer",
      args: [to, parseUnits(amount, 6)], // EURC has 6 decimals
    });

    setIsPending(true);
    try {
      const result = await sendUserOperation({
        evmSmartAccount: smartAccount,
        network: "base",
        calls: [
          {
            to: eurcContractAddress,
            value: 0n,
            data,
          },
        ],
      });

      setTxHash(result.userOperationHash);
      window.getTxHashOutOfWeb = () => result.userOperationHash;
    } catch (e) {
      const msg = JSON.stringify(e).toString() ?? "Transaction failed";
      toast.error(msg);
      return;
    } finally {
      setIsPending(false);
    }
  };

  return (
    <div style={ui.page}>
      <div style={ui.shell}>
        <div style={ui.card}>
          <div style={ui.header}>
            <div style={{ display: "grid", gap: 2 }}>
              <div style={ui.title}>Review payment</div>
              <div style={ui.subtitle}>Confirm the details before sending.</div>
            </div>
            <div style={ui.pill}>
              <span style={ui.pillLabel}>From</span>
              <span style={ui.pillValue}>
                {smartAccount
                  ? `${smartAccount.slice(0, 6)}…${smartAccount.slice(-4)}`
                  : "—"}
              </span>
            </div>
          </div>

          <div style={ui.hr} />

          <div style={ui.section}>
            <div style={ui.bigAmount}>{amountLabel}</div>
            <div style={ui.smallMuted}>You are sending</div>
          </div>

          <div style={ui.section}>
            <div style={ui.label}>To</div>
            <div style={ui.monoWrap} title={to}>
              {to || "—"}
            </div>
          </div>

          {metaLabel ? (
            <div style={ui.section}>
              <div style={ui.title}>{receiver || "—"}</div>
              <div style={ui.monoHint}>Receiver</div>

              <br />
              {description ? (
                <>
                  <div style={ui.meta}>{description}</div>
                  <div style={ui.monoHint}>Note</div>
                </>
              ) : null}
            </div>
          ) : null}

          {!to || !amount ? (
            <div style={ui.warn}>
              Missing URL params. Required:{" "}
              <code>?to=0x…&amp;amount=12.34</code>
            </div>
          ) : !isValid ? (
            <div style={ui.warn}>
              Invalid params. Expected: <code>to=0x&lt;40 hex&gt;</code> and{" "}
              <code>amount&gt;0</code>.
            </div>
          ) : null}

          <button
            onClick={handlePay}
            disabled={isPending || !smartAccount || !isValid}
            style={{
              ...ui.button,
              ...(isPending || !smartAccount || !isValid
                ? ui.buttonDisabled
                : {}),
            }}
          >
            {isPending ? "Processing…" : "Confirm Payment"}
          </button>

          {txHash ? (
            <div style={ui.success}>
              Sent. Tx:{" "}
              <span style={ui.monoInline} title={txHash}>
                {txHash.slice(0, 10)}…{txHash.slice(-8)}
              </span>
            </div>
          ) : null}
        </div>
      </div>
    </div>
  );
};

const ui: Record<string, React.CSSProperties> = {
  page: {
    width: "100%",
  },
  shell: {
    width: "100%",
    maxWidth: 520,
    margin: "0 auto",
    padding: "12px 12px 20px",
    boxSizing: "border-box",
  },
  card: {
    borderRadius: 16,
    border: "1px solid rgba(255,255,255,0.12)",
    background: "rgba(0,0,0,0.18)",
    boxShadow: "0 12px 28px rgba(0,0,0,0.35)",
    padding: 14,
  },
  header: {
    display: "flex",
    alignItems: "flex-start",
    justifyContent: "space-between",
    gap: 10,
  },
  title: { fontSize: 16, fontWeight: 800, letterSpacing: 0.2 },
  subtitle: { fontSize: 12, opacity: 0.75 },
  pill: {
    borderRadius: 999,
    border: "1px solid rgba(34,197,94,0.35)",
    background: "rgba(34,197,94,0.12)",
    padding: "6px 10px",
    display: "inline-flex",
    alignItems: "center",
    gap: 8,
    flexShrink: 0,
    maxWidth: "55%",
  },
  pillLabel: { fontSize: 11, opacity: 0.8 },
  pillValue: {
    fontSize: 12,
    fontWeight: 700,
    fontFamily: "ui-monospace, SFMono-Regular, Menlo, monospace",
    overflow: "hidden",
    textOverflow: "ellipsis",
    whiteSpace: "nowrap",
  },
  hr: { height: 1, background: "rgba(255,255,255,0.10)", margin: "12px 0" },
  section: { display: "grid", gap: 6, marginBottom: 12 },
  bigAmount: { fontSize: 28, fontWeight: 900, letterSpacing: -0.2 },
  smallMuted: { fontSize: 12, opacity: 0.7 },
  label: { fontSize: 12, opacity: 0.7 },
  monoWrap: {
    fontFamily: "ui-monospace, SFMono-Regular, Menlo, monospace",
    fontSize: 13,
    lineHeight: 1.3,
    wordBreak: "break-all",
    borderRadius: 12,
    border: "1px solid rgba(255,255,255,0.10)",
    background: "rgba(255,255,255,0.05)",
    padding: "10px 10px",
  },
  monoHint: {
    fontSize: 12,
    opacity: 0.75,
    fontFamily: "ui-monospace, SFMono-Regular, Menlo, monospace",
  },
  meta: {
    fontSize: 13,
    opacity: 0.9,
    lineHeight: 1.35,
  },
  warn: {
    marginTop: 6,
    marginBottom: 12,
    borderRadius: 12,
    border: "1px solid rgba(245,158,11,0.35)",
    background: "rgba(245,158,11,0.10)",
    padding: "10px 10px",
    fontSize: 12,
    lineHeight: 1.4,
  },
  button: {
    width: "100%",
    height: 48,
    borderRadius: 12,
    border: "1px solid rgba(255,255,255,0.14)",
    background:
      "linear-gradient(135deg, rgba(59,130,246,0.9), rgba(168,85,247,0.9))",
    color: "#fff",
    fontWeight: 800,
    fontSize: 14,
    cursor: "pointer",
  },
  buttonDisabled: {
    opacity: 0.5,
    cursor: "not-allowed",
  },
  success: {
    marginTop: 12,
    fontSize: 12,
    opacity: 0.9,
  },
  monoInline: {
    fontFamily: "ui-monospace, SFMono-Regular, Menlo, monospace",
    fontWeight: 700,
  },
};
