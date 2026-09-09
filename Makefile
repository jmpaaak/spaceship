LOVE ?= love
ZIP ?= zip
BUILD_DIR ?= build
LOVE_PACKAGE ?= $(BUILD_DIR)/game.love

.PHONY: test smoke love verify clean

HEADLESS_ENV = GAME_HEADLESS=1 SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy

test:
	$(HEADLESS_ENV) GAME_UNIT=1 $(LOVE) .
	python3 -m unittest tools.test_verify_asset_manifest tools.test_celestial_asset_baseline tools.test_celestial_asset_studio_manifest tools.test_legacy_asset_studio_removed tools.test_gear_editor_locale tools.test_gear_editor_engine_tab tools.test_project_skills -v

smoke:
	$(HEADLESS_ENV) $(LOVE) .

love:
	@mkdir -p "$(BUILD_DIR)"
	@rm -f "$(LOVE_PACKAGE)"
	@$(ZIP) -q -9 -r "$(LOVE_PACKAGE)" . \
		-x '.git' -x '.git/*' -x '.github/*' -x 'build/*' -x 'loop/*' \
		-x 'tmp/*' -x 'logs/*' -x '.venv/*' -x '.hermes/*' -x '__pycache__/*' \
		-x '.env' -x '.env.*' -x '.DS_Store' -x '*.swp'

verify: test smoke love
	$(HEADLESS_ENV) $(LOVE) "$(LOVE_PACKAGE)"
	python3 tools/verify_bundle.py "$(LOVE_PACKAGE)"
	python3 tools/verify_asset_manifest.py

clean:
	rm -rf "$(BUILD_DIR)"
