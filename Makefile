.PHONY: install lint test run run-gui

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
