# Load environment variables from ENV_FILE (default: local staging `.env`).
# Prod device builds: `make run-release-mobile-prod` → `.env.production`.
ENV_FILE ?= .env
-include $(ENV_FILE)
export

WEB3AUTH_CLIENT_ID ?= $(WEB3AUTH_ANDROID_CLIENT_ID)
DEVICE ?=
DEVICE_FLAG=$(if $(DEVICE),-d $(DEVICE),)

CLIENT_DART_DEFINES=--dart-define=APP_ENV=$(APP_ENV) \
	--dart-define=SUPABASE_URL=$(SUPABASE_URL) \
	--dart-define=EXPRESS_SERVER_URL=$(EXPRESS_SERVER_URL) \
	--dart-define=WALLET_CLIENT_URL=$(WALLET_CLIENT_URL) \
	--dart-define=APP_BASE_URL=$(APP_BASE_URL) \
	--dart-define=SUPABASE_ANON_KEY=$(SUPABASE_ANON_KEY) \
	--dart-define=GOOGLE_WEB_CLIENT_ID=$(GOOGLE_WEB_CLIENT_ID) \
	--dart-define=GOOGLE_ANDROID_CLIENT_ID=$(GOOGLE_ANDROID_CLIENT_ID) \
	--dart-define=GOOGLE_IOS_CLIENT_ID=$(GOOGLE_IOS_CLIENT_ID) \
	--dart-define=WEB3AUTH_CLIENT_ID=$(WEB3AUTH_CLIENT_ID) \
	--dart-define=WEB3AUTH_NETWORK=$(WEB3AUTH_NETWORK) \
	--dart-define=ALCHEMY_NETWORK_URL=$(ALCHEMY_NETWORK_URL) \
	--dart-define=MONERIUM_NETWORK_ADDRESS=$(MONERIUM_NETWORK_ADDRESS) \
	--dart-define=MONERIUM_WALLET_CHAIN=$(MONERIUM_WALLET_CHAIN)

.PHONY: help build-web build-aab build-ipa build-aab-prod build-ipa-prod \
	run-web run-mobile run-release-mobile run-release-mobile-prod \
	check-prod-env clean test deploy-web deploy-web-prod

help:
	@echo "Available commands:"
	@echo "  make build-aab                          - Play Store Android App Bundle (uses ENV_FILE, default .env)"
	@echo "  make build-ipa                          - iOS IPA (uses ENV_FILE, default .env)"
	@echo "  make build-aab-prod                     - Internal/prod AAB from .env.production"
	@echo "  make build-ipa-prod                     - TestFlight IPA from .env.production"
	@echo "  make build-web                          - Web build (uses ENV_FILE, default .env)"
	@echo "  make run-web                            - Run web in development mode"
	@echo "  make run-mobile DEVICE=Dennis           - Run on a named device (staging .env)"
	@echo "  make run-release-mobile DEVICE=Dennis   - Release run on a named device"
	@echo "  make run-release-mobile-prod DEVICE=…   - Release run against prod stack"
	@echo "  make clean                              - Clean build artifacts"
	@echo "  make deploy-web                         - Build+deploy Flutter web to slickbills-app (staging)"
	@echo "  make deploy-web-prod                    - Build+deploy Flutter web to slickbills-app-prod"

check-prod-env:
	@test -f .env.production || (echo "Missing .env.production — copy .env.production.example and fill secrets." && exit 1)
	@grep -q '^APP_ENV=production' .env.production || (echo ".env.production must set APP_ENV=production" && exit 1)

build-web:
	@echo "🚀 Building web with publishable client keys from $(ENV_FILE)..."
	flutter build web --no-tree-shake-icons --no-wasm-dry-run $(CLIENT_DART_DEFINES) --release

build-aab:
	@echo "📦 Building Play Store AAB from $(ENV_FILE)..."
	flutter build appbundle --release $(CLIENT_DART_DEFINES)

build-ipa:
	@echo "📦 Building iOS IPA from $(ENV_FILE)..."
	flutter build ipa --release $(CLIENT_DART_DEFINES)

build-aab-prod: check-prod-env
	$(MAKE) build-aab ENV_FILE=.env.production

build-ipa-prod: check-prod-env
	$(MAKE) build-ipa ENV_FILE=.env.production

run-web:
	@echo "🌐 Running web in development mode..."
	flutter run -d chrome $(CLIENT_DART_DEFINES)

run-mobile:
	@echo "📱 Running on mobile from $(ENV_FILE)..."
	flutter run $(DEVICE_FLAG) $(CLIENT_DART_DEFINES)

run-release-mobile:
	@echo "📱 Running release on mobile from $(ENV_FILE)..."
	flutter run --release $(DEVICE_FLAG) $(CLIENT_DART_DEFINES)

run-release-mobile-prod: check-prod-env
	$(MAKE) run-release-mobile ENV_FILE=.env.production

clean:
	@echo "🧹 Cleaning build artifacts..."
	flutter clean
	flutter pub get

test:
	@echo "🧪 Running tests..."
	flutter test

deploy-web: build-web
	@echo "🚀 Deploying Flutter web to slickbills-app (staging)..."
	VERCEL_ORG_ID=team_zHj53Y9qsJ0w95k4Aj0c6KXh \
	VERCEL_PROJECT_ID=prj_Y0QTGVzguHHXP3Ck8wpIitoehA6i \
	vercel deploy --prod --yes --cwd build/web

deploy-web-prod: check-prod-env
	$(MAKE) build-web ENV_FILE=.env.production
	@echo "🚀 Deploying Flutter web to slickbills-app-prod..."
	VERCEL_ORG_ID=team_zHj53Y9qsJ0w95k4Aj0c6KXh \
	VERCEL_PROJECT_ID=prj_LYf2DMN7BU40CZLqlWkvzJD5M23f \
	vercel deploy --prod --yes --cwd build/web
