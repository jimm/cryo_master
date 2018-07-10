NAME = cryo_master

all:
	crystal build 'src/cryo_master.cr' -o $(NAME)

release:
	crystal build 'src/cryo_master.cr' -o $(NAME) --release

spec:
test:
	crystal spec

clean:
	rm -f $(NAME) $(NAME).dwarf
