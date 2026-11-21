.PHONY: check install help

check:
	@find bin lib tests -type f -exec bash -n {} \;
	@bash -n install.sh
	@bash tests/smoke.sh

install:
	@bash install.sh

help:
	@bash bin/cbapp help
