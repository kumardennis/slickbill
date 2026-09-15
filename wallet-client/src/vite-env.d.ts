/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_APP_ENV?: string;
  readonly VITE_EXPRESS_SERVER_URL?: string;
  readonly VITE_WEB3AUTH_CLIENT_ID?: string;
  readonly VITE_WEB3AUTH_NETWORK?: string;
  readonly VITE_WEB3AUTH_FACEBOOK_AUTH_CONNECTION_ID?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
