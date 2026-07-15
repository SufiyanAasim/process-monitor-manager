.PHONY: install lint test run run-gui package deb

install:
	./scripts/install-deps.sh

lint:
	./scripts/lint.sh

test:
	./tests/smoke_test.sh

run:
	./monitor.sh

run-gui:
	./monitor.sh --gui

# Usage: make package VERSION=4.0.0
package:
	./scripts/package-release.sh $(VERSION)

# Usage: make deb VERSION=4.0.0
deb:
	./scripts/build-deb.sh $(VERSION)
