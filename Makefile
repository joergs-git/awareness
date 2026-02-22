APP_NAME = Awareness
BUILD_DIR = .build
BUNDLE_DIR = build/$(APP_NAME).app
CONTENTS_DIR = $(BUNDLE_DIR)/Contents
MACOS_DIR = $(CONTENTS_DIR)/MacOS
RESOURCES_DIR = $(CONTENTS_DIR)/Resources

.PHONY: build bundle run clean

build:
	swift build -c release

bundle: build
	@mkdir -p $(MACOS_DIR) $(RESOURCES_DIR)
	@cp $(BUILD_DIR)/release/$(APP_NAME) $(MACOS_DIR)/$(APP_NAME)
	@cp SupportFiles/Info.plist $(CONTENTS_DIR)/Info.plist
	@cp SupportFiles/AppIcon.icns $(RESOURCES_DIR)/AppIcon.icns
	@# Copy bundled resources if they exist
	@if [ -d "$(BUILD_DIR)/release/Awareness_Awareness.bundle" ]; then \
		cp -R "$(BUILD_DIR)/release/Awareness_Awareness.bundle" $(RESOURCES_DIR)/; \
	fi
	@codesign --force --sign - $(BUNDLE_DIR)
	@echo "Built $(BUNDLE_DIR)"

run: bundle
	@open $(BUNDLE_DIR)

clean:
	swift package clean
	rm -rf build/
