# Load KEY=VALUE from ENV_FILE (default: local staging `.env`).
# Do not `include` the file — Make treats `:` as rules, so comments like
# `Android: w3a://...` or a stray client id become `missing separator`.
# Prod Android: `make build-aab-prod`. Prod device: `make run-release-mobile-prod`.
ENV_FILE ?= .env
ifneq ($(wildcard $(ENV_FILE)),)
  $(foreach pair,$(shell grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$(ENV_FILE)"),$(eval export $(pair)))
endif

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

.PHONY: help build-web build-web-prod build-aab build-ipa build-aab-prod \
	build-ipa-prod run-web run-mobile run-release-mobile \
	run-release-mobile-prod check-prod-env bump-play-version clean test \
	deploy-web deploy-web-prod

# Play Store requires a unique versionCode per AAB. `1.0.0+35` → name 1.0.0, code 35.
# Skip with `make build-aab-prod BUMP_VERSION=0`.
BUMP_VERSION ?= 1

help:
	@echo "Available commands:"
	@echo "  make build-aab                          - Play Store Android App Bundle (uses ENV_FILE, default .env)"
	@echo "  make build-ipa                          - iOS IPA (uses ENV_FILE, default .env)"
	@echo "  make build-aab-prod                     - Internal/prod AAB from .env.production"
	@echo "  make build-ipa-prod                     - TestFlight IPA from .env.production"
	@echo "  make build-web                          - Flutter web (staging .env), no deploy"
	@echo "  make build-web-prod                     - Flutter web from .env.production + Vercel (app.slickbills.com)"
	@echo "  make deploy-web                         - Build+deploy Flutter web to slickbills-app (staging)"
	@echo "  make deploy-web-prod                    - Same as build-web-prod"
	@echo "  make run-web                            - Run web in development mode"
	@echo "  make run-mobile DEVICE=Dennis           - Run on a named device (staging .env)"
	@echo "  make run-release-mobile DEVICE=Dennis   - Release run on a named device"
	@echo "  make run-release-mobile-prod DEVICE=…   - Release run against prod stack"
	@echo "  make clean                              - Clean build artifacts"
	@echo "  Play Store AABs bump pubspec +build (versionCode). Skip: BUMP_VERSION=0"

check-prod-env:
	@test -f .env.production || (echo "Missing .env.production — copy .env.production.example and fill secrets." && exit 1)
	@grep -q '^APP_ENV=production' .env.production || (echo ".env.production must set APP_ENV=production" && exit 1)

bump-play-version:
ifeq ($(BUMP_VERSION),1)
	@python3 -c 'import pathlib,re,sys;p=pathlib.Path("pubspec.yaml");t=p.read_text();m=re.search(r"^(version:\s*)(\d+\.\d+\.\d+)\+(\d+)\s*$$",t,re.M); m or sys.exit("pubspec.yaml version must look like 0.1.1+32"); n=int(m.group(3))+1; p.write_text(t[:m.start()]+("%s%s+%d"%(m.group(1),m.group(2),n))+t[m.end():]); print("Bumped Play Store version to %s+%d (versionCode %d)"%(m.group(2),n,n))'
else
	@echo "Skipping version bump (BUMP_VERSION=$(BUMP_VERSION))"
endif

build-web:
	@echo "🚀 Building web with publishable client keys from $(ENV_FILE)..."
	flutter build web --no-tree-shake-icons --no-wasm-dry-run $(CLIENT_DART_DEFINES) --release

build-web-prod: check-prod-env
	$(MAKE) build-web ENV_FILE=.env.production
	@echo "🚀 Deploying Flutter web to slickbills-app-prod (app.slickbills.com)..."
	VERCEL_ORG_ID=team_zHj53Y9qsJ0w95k4Aj0c6KXh \
	VERCEL_PROJECT_ID=prj_LYf2DMN7BU40CZLqlWkvzJD5M23f \
	vercel deploy --prod --yes --cwd build/web

build-aab: bump-play-version
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

deploy-web-prod: build-web-prod
