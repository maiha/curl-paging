DOCKER_IMAGE = crystallang/crystal:1.19.0-dev-alpine
DOCKER_RUN = docker run --rm -v $(CURDIR):/app -w /app $(DOCKER_IMAGE)
BINARY = mock-server

.PHONY: build deps clean

build: $(BINARY)

$(BINARY): src/*.cr shard.yml lib
	$(DOCKER_RUN) crystal build --static src/main.cr -o $(BINARY)

lib: shard.yml
	$(DOCKER_RUN) shards install
	touch lib

clean:
	rm -f $(BINARY)
	rm -rf lib .shards
