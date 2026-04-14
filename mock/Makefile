DOCKER_IMAGE = crystallang/crystal:1.19.1-alpine
DOCKER_RUN = docker run --rm -u $(shell id -u):$(shell id -g) -v $(CURDIR):/app -w /app $(DOCKER_IMAGE)
BINARY = mock-server

.PHONY: build deps clean

build: $(BINARY) ## Build binary

$(BINARY): src/*.cr shard.yml lib
	$(DOCKER_RUN) crystal build --static src/main.cr -o $(BINARY)

lib: shard.yml ## Install dependencies
	$(DOCKER_RUN) sh -c 'shards install && touch lib'

clean: ## Clean build artifacts
	rm -f $(BINARY)
	rm -rf lib .shards
