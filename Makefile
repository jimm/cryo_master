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

.PHONY: clean
clean:
	rm -rf $(NAME) $(NAME).dwarf bin
