all: data

tacofancier.js: tacofancier.coffee
	coffee --compile tacofancier.coffee

tacofancy:
	rm -rf tacofancy
	wget https://github.com/sinker/tacofancy/archive/master.zip
	unzip master.zip
	mv tacofancy-master tacofancy
	rm master.zip

data: tacofancier.js tacofancy
	node tacofancier.js local

upload:
	iron_worker upload --worker-config env.yml

clean:
	rm -rf build