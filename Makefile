DOCKER_IMAGE = crystallang/crystal:1.19.1-alpine
DOCKER_RUN = docker run --rm -u $(shell id -u):$(shell id -g) -v $(CURDIR):/app -w /app $(DOCKER_IMAGE)
BINARY = curl-paging

.PHONY: help build mock test clean

help: ## Show available tasks
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-12s %s\n", $$1, $$2}'

build: $(BINARY) ## Build binary

$(BINARY): src/*.cr
	$(DOCKER_RUN) crystal build --static --release src/main.cr -o $(BINARY)

mock: ## Build mock server
	$(MAKE) -C mock

test: build mock ## Run tests
	$(MAKE) -C test

clean: ## Clean build artifacts
	rm -f $(BINARY)
	rm -rf paging/
	$(MAKE) -C mock clean
	$(MAKE) -C test clean
