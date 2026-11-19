.DEFAULT_GOAL := help
.PHONY: help run app check site release publish vm vm-push vm-record vm-restart vm-stop website-check

VM := scripts/vm.sh

help: ## Show this help
	@echo "Clawd. Usage: make <task>"
	@awk 'BEGIN {FS = ":.*## "} /^##@/ {printf "\n%s\n", substr($$0, 5)} /^[a-z-]+:.*## / {printf "  %-12s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo
	@echo "The site deploys itself when main changes. VM tasks need TART_HOME set if the VMs are not in tart's default folder."

##@ Run
run: ## Build the Mac app and open it
	$(MAKE) -C apps/clawd run

app: ## Build the Mac app into apps/clawd/dist without opening it
	$(MAKE) -C apps/clawd app

site: ## Serve the website at http://localhost:8000
	cd apps/website && python3 -m http.server 8000

##@ Test
check: website-check ## Run everything CI would: site checks, build, and tests
	$(MAKE) -C apps/clawd check

# Every act listed in the page must have its animation and its thumbnail.
website-check:
	python3 apps/website/scripts/check-acts.py

##@ Deploy
release: ## Build, sign, and notarize the disk image for the version in apps/clawd/VERSION
	$(MAKE) -C apps/clawd release

publish: ## Publish that disk image as a GitHub release and bump the Homebrew cask
	scripts/publish.sh

##@ Test VM
vm: ## Boot the macOS test VM with a visible window and wait for its desktop
	$(VM) up

vm-push: ## Build the app and test tools and copy them into the VM
	$(VM) push

vm-record: ## Film the VM window: make vm-record SECONDS=30 OUT=clip.mov
	$(VM) record $(or $(SECONDS),30) $(or $(OUT),vm.mov)

vm-restart: ## Reboot the VM
	$(VM) restart

vm-stop: ## Shut the VM down
	$(VM) stop
