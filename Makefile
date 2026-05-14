NAME := SYSTORE
SCHEME := Feather
PLATFORMS := iphoneos maccatalyst

CERT_JSON_URL := https://backloop.dev/pack.json

.PHONY: all clean deps $(PLATFORMS)

all: $(PLATFORMS)

clean:
	rm -rf build_temp packages Payload _build deps cert.json

deps:
	rm -rf deps || true
	mkdir -p deps
	curl -fsSL "$(CERT_JSON_URL)" -o cert.json
	jq -r '.cert' cert.json > deps/server.crt
	jq -r '.key1, .key2' cert.json > deps/server.pem
	jq -r '.info.domains.commonName' cert.json > deps/commonName.txt

$(PLATFORMS): deps
	rm -rf packages _build/Payload
	mkdir -p _build/Payload packages

	@set -e; \
	if [ "$@" = "iphoneos" ]; then \
		DEST="generic/platform=iOS"; \
	else \
		DEST="generic/platform=macOS,variant=Mac Catalyst"; \
	fi; \
	xcodebuild \
		-project Feather.xcodeproj \
		-scheme $(SCHEME) \
		-configuration Release \
		-destination "$$DEST" \
		-derivedDataPath build_temp \
		-skipPackagePluginValidation \
		CODE_SIGNING_ALLOWED=NO \
		ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES=NO \
		IPHONEOS_DEPLOYMENT_TARGET=15.0; \
	\
	echo "🚀 Searching for the built Feather.app..."; \
	APP_PATH=$$(find . -type d -name "Feather.app" | grep -v "Payload" | head -n 1); \
	if [ -z "$$APP_PATH" ]; then \
		echo "❌ Error: Feather.app not found!"; \
		exit 1; \
	fi; \
	echo "✅ Found Feather.app at: $$APP_PATH"; \
	cp -R "$$APP_PATH" _build/Payload/; \
	chmod -R 0755 _build/Payload/Feather.app; \
	codesign --force --sign - --timestamp=none _build/Payload/Feather.app; \
	cp deps/* _build/Payload/Feather.app/ || true; \
	\
	if [ "$@" = "iphoneos" ]; then \
		ditto -c -k --sequesterRsrc --keepParent _build/Payload "packages/$(NAME).ipa"; \
	else \
		ditto -c -k --sequesterRsrc --keepParent _build/Payload/Feather.app "packages/$(NAME)_Catalyst.zip"; \
	fi
