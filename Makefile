APP_NAME = Awareness
BUILD_DIR = .build
BUNDLE_DIR = build/$(APP_NAME).app
CONTENTS_DIR = $(BUNDLE_DIR)/Contents
MACOS_DIR = $(CONTENTS_DIR)/MacOS
RESOURCES_DIR = $(CONTENTS_DIR)/Resources

# Developer ID identity for notarized direct distribution.
# Override on the command line: make bundle-signed DEVELOPER_ID="Developer ID Application: Name (TEAMID)"
DEVELOPER_ID ?= "Developer ID Application: YOUR_NAME (TEAM_ID)"

.PHONY: build bundle bundle-signed release-direct run clean

build:
	swift build -c release

bundle: build
	@mkdir -p $(MACOS_DIR) $(RESOURCES_DIR)
	@cp $(BUILD_DIR)/release/$(APP_NAME) $(MACOS_DIR)/$(APP_NAME)
	@cp SupportFiles/Info.plist $(CONTENTS_DIR)/Info.plist
	@cp SupportFiles/AppIcon.icns $(RESOURCES_DIR)/AppIcon.icns
	@# Copy resource files directly into Contents/Resources/ for Bundle.main access.
	@# We intentionally bypass SPM's Awareness_Awareness.bundle because its generated
	@# Bundle.module accessor resolves to the .app root, which breaks codesigning.
	@cp Sources/Awareness/Resources/awareness-gong.aiff $(RESOURCES_DIR)/
	@cp Sources/Awareness/Resources/awareness-gong-end.aiff $(RESOURCES_DIR)/
	@cp Sources/Awareness/Resources/default-blackout.png $(RESOURCES_DIR)/
	@codesign --force --sign - $(BUNDLE_DIR)
	@echo "Built $(BUNDLE_DIR)"

# Sign with Developer ID + hardened runtime for direct (non-App Store) distribution
bundle-signed: build
	@mkdir -p $(MACOS_DIR) $(RESOURCES_DIR)
	@cp $(BUILD_DIR)/release/$(APP_NAME) $(MACOS_DIR)/$(APP_NAME)
	@cp SupportFiles/Info.plist $(CONTENTS_DIR)/Info.plist
	@cp SupportFiles/AppIcon.icns $(RESOURCES_DIR)/AppIcon.icns
	@cp Sources/Awareness/Resources/awareness-gong.aiff $(RESOURCES_DIR)/
	@cp Sources/Awareness/Resources/awareness-gong-end.aiff $(RESOURCES_DIR)/
	@cp Sources/Awareness/Resources/default-blackout.png $(RESOURCES_DIR)/
	codesign --force --options runtime \
		--sign $(DEVELOPER_ID) \
		--entitlements SupportFiles/Awareness-Direct.entitlements \
		$(BUNDLE_DIR)
	@echo "Signed $(BUNDLE_DIR) with Developer ID"

# Create notarized release ZIP for direct distribution
release-direct: bundle-signed
	ditto -c -k --keepParent $(BUNDLE_DIR) build/Awareness.zip
	xcrun notarytool submit build/Awareness.zip \
		--keychain-profile "notarytool-profile" --wait
	xcrun stapler staple $(BUNDLE_DIR)
	@echo "Notarized and stapled $(BUNDLE_DIR)"

run: bundle
	@open $(BUNDLE_DIR)

clean:
	swift package clean
	rm -rf build/

# One-time setup for notarization credentials (run manually):
# xcrun notarytool store-credentials "notarytool-profile" \
#     --apple-id "joergsflow@gmail.com" --team-id YOUR_TEAM_ID
