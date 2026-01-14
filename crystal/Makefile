DOCKER_IMAGE = crystallang/crystal:1.19.0-dev-alpine
DOCKER_RUN = docker run --rm -v $(CURDIR):/app -w /app $(DOCKER_IMAGE)
BINARY = curl-paging

.PHONY: build clean

build: $(BINARY)

$(BINARY): src/*.cr
	$(DOCKER_RUN) crystal build --static --release src/main.cr -o $(BINARY)

clean:
	rm -f $(BINARY)
	rm -rf paging/
