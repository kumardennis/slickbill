import { createRoot } from "react-dom/client";
import "./index.css";
import App from "./App.tsx";
import React from "react";
import { MetamaskAuth } from "./pages/metamask/MetamaskAuth.tsx";
import processShim from "process";

const processRef = processShim as {
  nextTick?: (cb: () => void) => void;
};

if (typeof processRef.nextTick !== "function") {
  processRef.nextTick = (cb: () => void) => {
    Promise.resolve().then(cb);
  };
}

// Ensure global and imported `process` references are the same object.
(globalThis as { process?: typeof processRef }).process = processRef;

const isStandaloneMetamaskRoute =
  window.location.pathname === "/wallet/metamask-auth";

createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    {isStandaloneMetamaskRoute ? <MetamaskAuth /> : <App />}
  </React.StrictMode>,
);
