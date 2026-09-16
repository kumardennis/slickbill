import { createRoot } from "react-dom/client";
import "./index.css";
import App from "./App.tsx";
import React from "react";
import { Web3AuthProvider } from "@web3auth/modal/react";
import { PrivyAuth } from "./pages/privy/PrivyAuth";
import { PrivyRoot } from "./pages/privy/PrivyAuthRoot";
import { MoneriumSiwe } from "./pages/siwe/MoneriumSiwe";
import processShim from "process";
import { web3AuthContextConfig } from "./web3authContext";

const processRef = processShim as {
  nextTick?: (cb: () => void) => void;
};

if (typeof processRef.nextTick !== "function") {
  processRef.nextTick = (cb: () => void) => {
    Promise.resolve().then(cb);
  };
}

(globalThis as { process?: typeof processRef }).process = processRef;

const pathname = window.location.pathname;
const isPrivySiweRoute = pathname === "/wallet/siwe";
const isPrivyConnectRoute =
  pathname === "/wallet/privy-auth" || pathname === "/wallet/metamask-auth";

const root = (
  <React.StrictMode>
    {isPrivySiweRoute || isPrivyConnectRoute ? (
      <PrivyRoot>
        {isPrivySiweRoute ? <MoneriumSiwe /> : <PrivyAuth />}
      </PrivyRoot>
    ) : (
      <Web3AuthProvider config={web3AuthContextConfig}>
        <App />
      </Web3AuthProvider>
    )}
  </React.StrictMode>
);

createRoot(document.getElementById("root")!).render(root);
