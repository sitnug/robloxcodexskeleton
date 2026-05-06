ROJO_PROJECT ?= default.project.json
PLACE_FILE ?= build/testrblx.rbxlx

.PHONY: install doctor serve format format-check lint sourcemap build check clean

install:
	aftman install --no-trust-check
	wally install

doctor:
	aftman --version
	rojo --version
	stylua --version
	selene --version
	wally --version

serve:
	rojo serve $(ROJO_PROJECT)

format:
	stylua src

format-check:
	stylua --check src

lint:
	selene src

sourcemap:
	rojo sourcemap $(ROJO_PROJECT) -o sourcemap.json

build:
	mkdir -p build
	rojo build $(ROJO_PROJECT) -o $(PLACE_FILE)

check: format-check lint sourcemap build

clean:
	rm -rf build sourcemap.json Packages DevPackages
