NAME = cryo_master

all:
	crystal build 'src/cryo_master.cr' -o $(NAME)

release:
	crystal build 'src/cryo_master.cr' -o $(NAME) --release

test:
	crystal spec

spec:	test

clean:
	rm -f $(NAME) $(NAME).dwarf
