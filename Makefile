.PHONY: app install test icon run dmg clean

app:        ## Build build/Doppio.app
	scripts/build-app.sh

install:    ## Build and install to /Applications, then launch
	scripts/install.sh

test:       ## Run unit tests
	swift test

icon:       ## Regenerate Resources/AppIcon.icns
	scripts/make-icon.sh

run: app    ## Build and launch from build/
	open build/Doppio.app

dmg:        ## Build a universal DMG: make dmg VERSION=1.2.0
	scripts/package-release.sh $(VERSION)

clean:
	rm -rf .build build
