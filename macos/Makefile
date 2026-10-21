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
            -I. -Ithird_party/hunspell \
            -DHUNSPELL_STATIC
LDFLAGS  := -framework Cocoa -framework InputMethodKit -framework Carbon -framework Foundation

# Optional: ARCHS="arm64 x86_64" for a universal release binary
ifneq ($(strip $(ARCHS)),)
  ARCH_FLAGS := $(foreach a,$(ARCHS),-arch $(a))
  CXXFLAGS   += $(ARCH_FLAGS)
  LDFLAGS    += $(ARCH_FLAGS)
endif

CPP_SRCS := Composer.cpp CompString.cpp InputContext.cpp Globals.cpp HelperFunctions.cpp
MM_SRCS  := Init.mm BuuzInputController.mm SpellChecker.mm

HUNSPELL_DIR  := third_party/hunspell
HUNSPELL_SRCS := affentry.cxx affixmgr.cxx csutil.cxx filemgr.cxx hashmgr.cxx \
                 hunspell.cxx hunzip.cxx phonet.cxx replist.cxx suggestmgr.cxx
HUNSPELL_OBJS := $(addprefix $(BUILD_DIR)/hunspell/,$(HUNSPELL_SRCS:.cxx=.o))

CPP_OBJS := $(addprefix $(BUILD_DIR)/,$(CPP_SRCS:.cpp=.o))
MM_OBJS  := $(addprefix $(BUILD_DIR)/,$(MM_SRCS:.mm=.o))
OBJS     := $(CPP_OBJS) $(MM_OBJS) $(HUNSPELL_OBJS)

DICT_DIR := Resources/dict
DICT_AFF := $(DICT_DIR)/mn_MN.aff
DICT_DIC := $(DICT_DIR)/mn_MN.dic
DICT_FREQ := $(DICT_DIR)/mn_freq.txt

.PHONY: all clean install uninstall reinstall package dict test-spell eval-spell

all: dict $(BUILD_DIR)/$(APP_BUNDLE)

dict: $(DICT_AFF) $(DICT_DIC)

$(DICT_AFF) $(DICT_DIC):
	./fetch-dict.sh

$(BUILD_DIR)/$(APP_BUNDLE): $(OBJS) Info.plist $(DICT_AFF) $(DICT_DIC) $(DICT_FREQ) Resources/en.lproj/InfoPlist.strings
	@mkdir -p $(MACOS_DIR) $(RES_DIR)/dict $(RES_DIR)/en.lproj
	$(OBJCXX) $(OBJS) -o $(MACOS_DIR)/$(APP_NAME) $(LDFLAGS)
	cp Info.plist $(CONTENTS)/
	cp Resources/en.lproj/InfoPlist.strings $(RES_DIR)/en.lproj/
	cp Resources/buuzTemplate.tiff $(RES_DIR)/
	cp $(DICT_AFF) $(DICT_DIC) $(DICT_FREQ) $(RES_DIR)/dict/
	@if [ -f $(DICT_DIR)/LICENSE ]; then cp $(DICT_DIR)/LICENSE $(RES_DIR)/dict/; fi
	@if [ -f $(DICT_DIR)/README.md ]; then cp $(DICT_DIR)/README.md $(RES_DIR)/dict/; fi
	codesign --force --deep --sign - $(BUILD_DIR)/$(APP_BUNDLE) 2>/dev/null || true
	@echo "Built $(BUILD_DIR)/$(APP_BUNDLE)"

$(BUILD_DIR)/%.o: %.cpp
	@mkdir -p $(BUILD_DIR)
	$(CXX) $(CXXFLAGS) -c $< -o $@

$(BUILD_DIR)/%.o: %.mm
	@mkdir -p $(BUILD_DIR)
	$(OBJCXX) $(CXXFLAGS) -c $< -o $@

$(BUILD_DIR)/hunspell/%.o: $(HUNSPELL_DIR)/%.cxx
	@mkdir -p $(BUILD_DIR)/hunspell
	$(CXX) $(filter-out -fobjc-arc,$(CXXFLAGS)) -w -c $< -o $@

clean:
	rm -rf $(BUILD_DIR)

install: all
	./install.sh

uninstall:
	./install.sh --uninstall

reinstall: uninstall install

test-spell: dict $(HUNSPELL_OBJS) $(BUILD_DIR)/SpellChecker.o
	$(OBJCXX) $(CXXFLAGS) test_spell.mm $(BUILD_DIR)/SpellChecker.o $(HUNSPELL_OBJS) \
	  -framework Foundation -o $(BUILD_DIR)/test_spell $(ARCH_FLAGS)
	$(BUILD_DIR)/test_spell $(DICT_DIR)

# Autocorrect accuracy on simulated Latin typing; SHOW=1 lists failures.
eval-spell: dict $(CPP_OBJS) $(HUNSPELL_OBJS) $(BUILD_DIR)/SpellChecker.o
	$(OBJCXX) $(CXXFLAGS) tools/eval_spell.mm $(CPP_OBJS) $(BUILD_DIR)/SpellChecker.o \
	  $(HUNSPELL_OBJS) -framework Foundation -o $(BUILD_DIR)/eval_spell $(ARCH_FLAGS)
	$(BUILD_DIR)/eval_spell $(DICT_DIR) $(WORDS)

# Universal .app zip for GitHub Releases / Homebrew Cask
package: clean
	$(MAKE) ARCHS="arm64 x86_64" all
	./package-release.sh
