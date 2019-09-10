zip:
	cd .. && zip -r mt-plugin-shared-preview/mt-plugin-shared-preview.zip mt-plugin-shared-preview -x *.git* */SharedPreview/t/* */.travis.yml */Makefile *node_modules* *.circleci* *package.json *yarn.lock *.node-version

clean:
	rm mt-plugin-shared-preview.zip

