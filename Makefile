LOVE ?= love
ZIP ?= zip
BUILD_DIR ?= build
LOVE_PACKAGE ?= $(BUILD_DIR)/game.love

.PHONY: test smoke love verify clean

test:
	GAME_HEADLESS=1 GAME_UNIT=1 $(LOVE) .

smoke:
	GAME_HEADLESS=1 $(LOVE) .

love:
	@mkdir -p "$(BUILD_DIR)"
	@rm -f "$(LOVE_PACKAGE)"
	@$(ZIP) -q -9 -r "$(LOVE_PACKAGE)" . \
		-x '.git' -x '.git/*' -x '.github/*' -x 'build/*' \
		-x 'tmp/*' -x 'logs/*' -x '.venv/*' -x '__pycache__/*' \
		-x '.env' -x '.env.*' -x '.DS_Store' -x '*.swp'

verify: test smoke love
	GAME_HEADLESS=1 $(LOVE) "$(LOVE_PACKAGE)"
	python3 tools/verify_bundle.py "$(LOVE_PACKAGE)"

clean:
	rm -rf "$(BUILD_DIR)"
