# Buuz macOS Input Method
#
# Builds Buuz.app — same conversion engine as the Windows IME.
#
# Release (universal): make clean && make ARCHS="arm64 x86_64"

APP_NAME   := Buuz
APP_BUNDLE := $(APP_NAME).app
BUILD_DIR  := build
CONTENTS   := $(BUILD_DIR)/$(APP_BUNDLE)/Contents
MACOS_DIR  := $(CONTENTS)/MacOS
RES_DIR    := $(CONTENTS)/Resources

CXX      := clang++
OBJCXX   := clang++
CXXFLAGS := -std=c++17 -O2 -fobjc-arc \
            -Wall -Wno-unused-parameter \
            -I.
LDFLAGS  := -framework Cocoa -framework InputMethodKit -framework Carbon

# Optional: ARCHS="arm64 x86_64" for a universal release binary
ifneq ($(strip $(ARCHS)),)
  ARCH_FLAGS := $(foreach a,$(ARCHS),-arch $(a))
  CXXFLAGS   += $(ARCH_FLAGS)
  LDFLAGS    += $(ARCH_FLAGS)
endif

CPP_SRCS := Composer.cpp CompString.cpp InputContext.cpp Globals.cpp HelperFunctions.cpp
MM_SRCS  := Init.mm BuuzInputController.mm

CPP_OBJS := $(addprefix $(BUILD_DIR)/,$(CPP_SRCS:.cpp=.o))
MM_OBJS  := $(addprefix $(BUILD_DIR)/,$(MM_SRCS:.mm=.o))
OBJS     := $(CPP_OBJS) $(MM_OBJS)

.PHONY: all clean install uninstall reinstall package

all: $(BUILD_DIR)/$(APP_BUNDLE)

$(BUILD_DIR)/$(APP_BUNDLE): $(OBJS) Info.plist
	@mkdir -p $(MACOS_DIR) $(RES_DIR)
	$(OBJCXX) $(OBJS) -o $(MACOS_DIR)/$(APP_NAME) $(LDFLAGS)
	cp Info.plist $(CONTENTS)/
	@if [ -f Resources/buuz.tiff ]; then cp Resources/buuz.tiff $(RES_DIR)/; \
	 elif [ -f Resources/buuz.ico ]; then \
	   sips -s format tiff Resources/buuz.ico --out $(RES_DIR)/buuz.tiff 2>/dev/null || true; \
	 fi
	codesign --force --deep --sign - $(BUILD_DIR)/$(APP_BUNDLE) 2>/dev/null || true
	@echo "Built $(BUILD_DIR)/$(APP_BUNDLE)"

$(BUILD_DIR)/%.o: %.cpp
	@mkdir -p $(BUILD_DIR)
	$(CXX) $(CXXFLAGS) -c $< -o $@

$(BUILD_DIR)/%.o: %.mm
	@mkdir -p $(BUILD_DIR)
	$(OBJCXX) $(CXXFLAGS) -c $< -o $@

clean:
	rm -rf $(BUILD_DIR)

install: all
	./install.sh

uninstall:
	./install.sh --uninstall

reinstall: uninstall install

# Universal .app zip for GitHub Releases / Homebrew Cask
package: clean
	$(MAKE) ARCHS="arm64 x86_64" all
	./package-release.sh
