# Tacofancier

[Tacofancy](https://github.com/sinker/tacofancy) extracted recipes. Get it? Taco recipes in structured JSON. Generates both individual recipe files, collections (layers, condiments, mixins, seasonings, shells) and subsets per type of meat.

### Status

The current code, as-is, produces an [all.json](https://s3.amazonaws.com/tacofancier/all.json) that contains every recipe, split up by category, so the basic thing works. [Download it here](https://s3.amazonaws.com/tacofancier/all.json).

Still have to split out the data into various useful subsets though, like all vegetarian recipes, all the different categories et cetera.

[x] collect all recipes, process them, but 'em in a big JSON file
[x] use github to figure out each recipe's author and contributors
[x] run Tacofancier on [IronWorker](http://www.iron.io/worker) and upload to [S3](http://aws.amazon.com/s3)
[ ] output aggregations: vegan, vegetarian, protein type, meat type, category, everything
[ ] individual recipe output in JSON and YAML
[ ] process links to figure out recipe relationships

### Why?

Tacofancy is a potentially fun dataset to toy around with for data analysis or for teaching people how to build websites. But if it ain't JSON, it's kind of hard to play with.