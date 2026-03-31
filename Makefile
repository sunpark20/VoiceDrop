APP_NAME    = QuickNoteObsidian
SRC_DIR     = $(APP_NAME)
SOURCES     = $(wildcard $(SRC_DIR)/*.swift)
BUILD_DIR   = build
APP_BUNDLE  = $(BUILD_DIR)/$(APP_NAME).app
CONTENTS    = $(APP_BUNDLE)/Contents
MACOS_DIR   = $(CONTENTS)/MacOS

SWIFT_FLAGS = -parse-as-library -framework AppKit -framework ApplicationServices

.PHONY: build clean run debug

build: $(APP_BUNDLE)

$(APP_BUNDLE): $(SOURCES) $(SRC_DIR)/Info.plist
	@mkdir -p $(MACOS_DIR)
	swiftc $(SWIFT_FLAGS) -O $(SOURCES) -o $(MACOS_DIR)/$(APP_NAME)
	@cp $(SRC_DIR)/Info.plist $(CONTENTS)/Info.plist
	@echo "✅ Built: $(APP_BUNDLE)"

debug: $(SOURCES) $(SRC_DIR)/Info.plist
	@mkdir -p $(MACOS_DIR)
	swiftc $(SWIFT_FLAGS) -g $(SOURCES) -o $(MACOS_DIR)/$(APP_NAME)
	@cp $(SRC_DIR)/Info.plist $(CONTENTS)/Info.plist
	@echo "✅ Debug built: $(APP_BUNDLE)"

run: build
	@open $(APP_BUNDLE)

run-debug: debug
	$(MACOS_DIR)/$(APP_NAME)

clean:
	rm -rf $(BUILD_DIR)
