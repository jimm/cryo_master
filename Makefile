NAME = cryo_master

.PHONY: all
all:	build

.PHONY: build
build:
	shards build

.PHONY: release
release:
	shards build --release

.PHONY: test
test:
	crystal spec

.PHONY: spec
spec:	test

.PHONY: clean
clean:
	rm -f $(NAME) $(NAME).dwarf
