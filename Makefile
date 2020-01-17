NAME = cryo_master

.PHONY: all
all:	build

.PHONY: build
build:
	shards build

.PHONY: release
release:
	shards build --release

.PHONY: spec
spec:
	crystal spec

.pyony: test
test:
	crystal spec spec/*_spec.cr

.PHONY: clean
clean:
	rm -rf $(NAME) $(NAME).dwarf bin
