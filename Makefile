PKG_MANAGER := $(shell if command -v apt-get >/dev/null 2>&1; then echo apt; elif command -v brew >/dev/null 2>&1; then echo brew; fi)

deps:
	@if command -v fping >/dev/null 2>&1; then echo "fping already installed"; \
	elif [ "$(PKG_MANAGER)" = "apt" ]; then sudo apt-get update && sudo apt-get install -y fping; \
	elif [ "$(PKG_MANAGER)" = "brew" ]; then brew install fping; \
	else echo "please install fping manually"; fi
	@if command -v arp-scan >/dev/null 2>&1; then echo "arp-scan already installed"; \
	elif [ "$(PKG_MANAGER)" = "apt" ]; then sudo apt-get update && sudo apt-get install -y arp-scan; \
	elif [ "$(PKG_MANAGER)" = "brew" ]; then brew install arp-scan; \
	else echo "please install arp-scan manually"; fi
	@if command -v bats >/dev/null 2>&1; then echo "bats already installed"; \
	elif [ "$(PKG_MANAGER)" = "apt" ]; then sudo apt-get update && sudo apt-get install -y bats; \
	elif [ "$(PKG_MANAGER)" = "brew" ]; then brew install bats-core; \
	else echo "please install bats manually"; fi

run:
	./monitor/watch-devices.sh

test:
	bats tests
