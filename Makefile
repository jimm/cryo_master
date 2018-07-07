NAME = cryo_master

all:
	crystal build `find src -name '*.cr'` -o $(NAME)

release:
	crystal build `find src -name '*.cr'` -o $(NAME) --release

clean:
	rm -f $(NAME) $(NAME).dwarf
