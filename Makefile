.PHONY: build1

build1:
	@make -C ./build

clean:
	find ./build -type f ! -name 'Makefile' ! -name 'README' -delete
