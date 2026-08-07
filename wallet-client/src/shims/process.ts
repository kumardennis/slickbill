type NextTickCallback = (...args: unknown[]) => void;

const runNextTick = (callback: NextTickCallback, args: unknown[]) => {
  Promise.resolve().then(() => {
    callback(...args);
  });
};

const processShim = {
  title: "browser",
  browser: true,
  env: {} as Record<string, string | undefined>,
  argv: [] as string[],
  version: "",
  versions: {} as Record<string, string>,
  platform: "browser",
  cwd: () => "/",
  nextTick: (callback: NextTickCallback, ...args: unknown[]) => {
    runNextTick(callback, args);
  },
  on: () => processShim,
  off: () => processShim,
  once: () => processShim,
  emit: () => false,
};

(globalThis as unknown as { process?: typeof processShim }).process =
  processShim;

export const {
  title,
  browser,
  env,
  argv,
  version,
  versions,
  platform,
  cwd,
  nextTick,
  on,
  off,
  once,
  emit,
} = processShim;

export default processShim;
