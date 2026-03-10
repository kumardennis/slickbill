# Load environment variables from .env file
include .env
export

.PHONY: help build-web run-web run-mobile clean test deploy-web

help:
	@echo "Available commands:"
	@echo "  make build-web    - Build web with environment variables"
	@echo "  make run-web      - Run web in development mode"
	@echo "  make run-mobile   - Run on mobile device"
	@echo "  make clean        - Clean build artifacts"
	@echo "  make test         - Run tests"

build-web:
	@echo "🚀 Building web with environment variables..."
	flutter build web --dart-define=SUPABASE_ANON_KEY=$(SUPABASE_ANON_KEY) --dart-define=GOOGLE_WEB_CLIENT_ID=$(GOOGLE_WEB_CLIENT_ID) --dart-define=GOOGLE_WEB_CLIENT_SECRET=$(GOOGLE_WEB_CLIENT_SECRET) --dart-define=GOOGLE_ANDROID_CLIENT_ID=$(GOOGLE_ANDROID_CLIENT_ID) --dart-define=GOOGLE_IOS_CLIENT_ID=$(GOOGLE_IOS_CLIENT_ID) --dart-define=OPEN_AI_KEY=$(OPEN_AI_KEY) --dart-define=ONESIGNAL_APP_ID=$(ONESIGNAL_APP_ID) --dart-define=ONESIGNAL_REST_API_KEY=$(ONESIGNAL_REST_API_KEY) --release

run-web:
	@echo "🌐 Running web in development mode..."
	flutter run -d chrome

run-mobile:
	@echo "📱 Running on mobile..."
	flutter run

clean:
	@echo "🧹 Cleaning build artifacts..."
	flutter clean
	flutter pub get

test:
	@echo "🧪 Running tests..."
	flutter test

deploy-web: build-web
	@echo "🚀 Deploying to production..."
