# Load environment variables from .env file
include .env
export

WEB3AUTH_CLIENT_ID ?= $(WEB3AUTH_ANDROID_CLIENT_ID)
DEVICE ?=
DEVICE_FLAG=$(if $(DEVICE),-d $(DEVICE),)

CLIENT_DART_DEFINES=--dart-define=SUPABASE_ANON_KEY=$(SUPABASE_ANON_KEY) \
	--dart-define=GOOGLE_WEB_CLIENT_ID=$(GOOGLE_WEB_CLIENT_ID) \
	--dart-define=GOOGLE_ANDROID_CLIENT_ID=$(GOOGLE_ANDROID_CLIENT_ID) \
	--dart-define=GOOGLE_IOS_CLIENT_ID=$(GOOGLE_IOS_CLIENT_ID) \
	--dart-define=WEB3AUTH_CLIENT_ID=$(WEB3AUTH_CLIENT_ID) \
	--dart-define=ALCHEMY_NETWORK_URL=$(ALCHEMY_NETWORK_URL) \
	--dart-define=MONERIUM_NETWORK_ADDRESS=$(MONERIUM_NETWORK_ADDRESS)

.PHONY: help build-web build-aab run-web run-mobile run-release-mobile clean test deploy-web

help:
	@echo "Available commands:"
	@echo "  make build-aab                          - Play Store Android App Bundle"
	@echo "  make build-web                          - Production web build"
	@echo "  make run-web                            - Run web in development mode"
	@echo "  make run-mobile DEVICE=Dennis           - Run on a named device"
	@echo "  make run-release-mobile DEVICE=Dennis   - Release run on a named device"
	@echo "  make clean                              - Clean build artifacts"
	@echo "  make test                               - Run tests"

build-web:
	@echo "🚀 Building web with publishable client keys..."
	flutter build web --no-tree-shake-icons --no-wasm-dry-run $(CLIENT_DART_DEFINES) --release

build-aab:
	@echo "📦 Building Play Store AAB with publishable client keys..."
	flutter build appbundle --release $(CLIENT_DART_DEFINES)

run-web:
	@echo "🌐 Running web in development mode..."
	flutter run -d chrome $(CLIENT_DART_DEFINES)

run-mobile:
	@echo "📱 Running on mobile..."
	flutter run $(DEVICE_FLAG) $(CLIENT_DART_DEFINES)

run-release-mobile:
	@echo "📱 Running release on mobile..."
	flutter run --release $(DEVICE_FLAG) $(CLIENT_DART_DEFINES)

clean:
	@echo "🧹 Cleaning build artifacts..."
	flutter clean
	flutter pub get

test:
	@echo "🧪 Running tests..."
	flutter test

deploy-web: build-web
	@echo "🚀 Deploying to production..."
