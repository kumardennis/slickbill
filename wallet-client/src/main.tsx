import { createRoot } from "react-dom/client";
import "./index.css";
import App from "./App.tsx";
import React from "react";
import { Web3AuthProvider } from "@web3auth/modal/react";
import { MetamaskAuth } from "./pages/metamask/MetamaskAuth.tsx";
import { PrivyAuthRoot } from "./pages/privy/PrivyAuthRoot";
import processShim from "process";
import {
  isWeb3AuthRedirectReturn,
  web3AuthContextConfig,
} from "./web3authContext";

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
const isStandalonePrivyRoute = pathname === "/wallet/privy-auth";
const isStandaloneMetamaskRoute =
  pathname === "/wallet/metamask-auth" || isWeb3AuthRedirectReturn();

const root = (
  <React.StrictMode>
    {isStandalonePrivyRoute ? (
      <PrivyAuthRoot />
    ) : (
      <Web3AuthProvider config={web3AuthContextConfig}>
        {isStandaloneMetamaskRoute ? <MetamaskAuth /> : <App />}
      </Web3AuthProvider>
    )}
  </React.StrictMode>
);

createRoot(document.getElementById("root")!).render(root);
