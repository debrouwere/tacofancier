all: data

tacofancier.js: tacofancier.coffee
	coffee --compile tacofancier.coffee

tacofancy:
	rm -rf tacofancy
	curl -O https://codeload.github.com/sinker/tacofancy/zip/master
	unzip master
	mv tacofancy-master tacofancy
	rm master

data: tacofancier.js tacofancy
	node tacofancier.js local

schedule:
	iron_worker schedule tacofancier --run-every 3600

upload: tacofancier.js tacofancier.worker env.yml
	yaml2json env.yml > env.json
	iron_worker upload tacofancier.worker \
		--worker-config env.json

clean:
	rm -rf build
