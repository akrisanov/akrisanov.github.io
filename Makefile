.PHONY: serve build

serve:  ## Run dev server
	bundle exec jekyll serve --baseurl=""

build:  ## Build an optimized site http://jekyllrb.com/docs/step-by-step/10-deployment/#environments
	JEKYLL_ENV=production bundle exec jekyll build
