SWIFT = swift
BUILD_DIR = .build
EXECUTABLE = clipslots
DEV_CERT = ClipSlots-Dev

.PHONY: all build build-debug clean run install setup-cert site app app-debug app-run app-install

all: build

# One-time: create a self-signed cert so Accessibility permission survives rebuilds
setup-cert:
	@if security find-identity -v -p codesigning | grep -q "$(DEV_CERT)"; then \
		echo "Certificate '$(DEV_CERT)' already exists."; \
	else \
		echo "Creating self-signed code-signing certificate '$(DEV_CERT)'..."; \
		openssl req -x509 -newkey rsa:2048 -keyout /tmp/clipslots-dev.key \
			-out /tmp/clipslots-dev.crt -days 3650 -nodes \
			-subj "/CN=$(DEV_CERT)" \
			-addext "keyUsage=digitalSignature" \
			-addext "extendedKeyUsage=codeSigning" 2>/dev/null; \
		openssl pkcs12 -export -out /tmp/clipslots-dev.p12 \
			-inkey /tmp/clipslots-dev.key -in /tmp/clipslots-dev.crt \
			-passout pass:clipslots -legacy 2>/dev/null; \
		security import /tmp/clipslots-dev.p12 -k ~/Library/Keychains/login.keychain-db \
			-T /usr/bin/codesign -P "clipslots"; \
		security find-certificate -c "$(DEV_CERT)" -p ~/Library/Keychains/login.keychain-db \
			> /tmp/clipslots-dev.pem; \
		openssl x509 -in /tmp/clipslots-dev.pem -out /tmp/clipslots-dev.cer -outform DER 2>/dev/null; \
		security add-trusted-cert -p codeSign -k ~/Library/Keychains/login.keychain-db \
			/tmp/clipslots-dev.cer; \
		rm -f /tmp/clipslots-dev.key /tmp/clipslots-dev.crt /tmp/clipslots-dev.p12 \
			/tmp/clipslots-dev.pem /tmp/clipslots-dev.cer; \
		echo "Certificate '$(DEV_CERT)' created and trusted for code signing."; \
	fi

build:
	$(SWIFT) build -c release
	@if security find-identity -v -p codesigning | grep -q "$(DEV_CERT)"; then \
		codesign -f -s "$(DEV_CERT)" ./$(BUILD_DIR)/release/$(EXECUTABLE); \
		echo "Signed with $(DEV_CERT)"; \
	fi
	@if launchctl list com.clipslots.daemon >/dev/null 2>&1; then \
		echo "Daemon running — restarting with new binary..."; \
		./$(BUILD_DIR)/release/$(EXECUTABLE) restart; \
	fi

build-debug:
	$(SWIFT) build
	@if security find-identity -v -p codesigning | grep -q "$(DEV_CERT)"; then \
		codesign -f -s "$(DEV_CERT)" ./$(BUILD_DIR)/debug/$(EXECUTABLE); \
		echo "Signed with $(DEV_CERT)"; \
	fi
	@if launchctl list com.clipslots.daemon >/dev/null 2>&1; then \
		echo "Daemon running — restarting with new binary..."; \
		./$(BUILD_DIR)/debug/$(EXECUTABLE) restart; \
	fi

clean:
	rm -rf $(BUILD_DIR) Package.resolved

run: build-debug
	./$(BUILD_DIR)/debug/$(EXECUTABLE)

install: build
	@echo "Installing to /usr/local/bin..."
	@sudo cp $(BUILD_DIR)/release/$(EXECUTABLE) /usr/local/bin/
	@echo "Installed successfully"

site:
	open docs/index.html

# Menubar app. Signed with the ClipSlots-Dev cert when present, so the
# Accessibility grant survives rebuilds (same trick as the CLI).
app:
	./scripts/build-app.sh

app-debug:
	./scripts/build-app.sh --debug

# Build, quit any running copy, and launch the fresh build from .build/
app-run: app
	@osascript -e 'quit app id "dev.clipslots.ClipSlots"' 2>/dev/null || true
	@sleep 0.5
	open $(BUILD_DIR)/ClipSlots.app

# Build and install to /Applications (stable path for the login item)
app-install: app
	@osascript -e 'quit app id "dev.clipslots.ClipSlots"' 2>/dev/null || true
	@sleep 0.5
	rm -rf /Applications/ClipSlots.app
	ditto $(BUILD_DIR)/ClipSlots.app /Applications/ClipSlots.app
	open /Applications/ClipSlots.app
	@echo "Installed /Applications/ClipSlots.app"
