.PHONY: all build mock test clean

all: build

build:
	$(MAKE) -C crystal

mock:
	$(MAKE) -C mock

test: build mock
	$(MAKE) -C test

clean:
	$(MAKE) -C crystal clean
	$(MAKE) -C mock clean
	$(MAKE) -C test clean
