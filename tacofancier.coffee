###
I want a pony: 

[ ] use github to figure out a recipe's author and contributors
[ ] output aggregations: vegan, vegetarian, protein type, meat type, category, everything
[ ] process links to figure out recipe relationships
###

_ = require 'underscore'
_.str = require 'underscore.string'
fs = require 'fs'
fs.path = require 'path'
fs.mkdirp = require 'mkdirp'
async = require 'async'
cheerio = require 'cheerio'
{markdown} = require 'markdown'
toHTML = _.bind markdown.toHTML, markdown

categories =
    layers: 'base_layers'
    tacos: 'full_tacos'
    more: 'like_tacos'
    condiments: 'condiments'
    mixins: 'mixins'
    seasonings: 'seasonings'
    shells: 'shells'

meats = [
    'beef'
    'chicken'
    'turkey'
    'fish'
    'pork'
    'lamb'
    ]

protein = [
    'seitan'
    'tempeh'
    'tofu'
    'quorn'
    'soyrizo'
    'tofurky'
    ]

github = 'https://api.github.com/repos/sinker/tacofancy/commits'
getContributors = (path, callback) ->
    params =
        uri: github
        qs: {path}
        json: yes
    request.get params, (err, res, commits) ->
        if err then return callback err

        contributors = commits.map (commit) ->
            contributor =
                name: commit.commit.author.name
                username: commit.author.login
        contributors = _.unique contributors, no, _.property 'username'
        author = _.last contributors

        callback null, author, contributors

behaved = (fn) ->
    (first) ->
        fn first

download = (callback) ->
    fs.exists 'tacofancy', (exists) ->
        if exists
            callback null
        else
            exec 'make tacofancy', (err) ->
                callback err

setup = (callback) ->
    fs.mkdirp 'data', behaved callback

read = (segments...) ->
    segments = segments.filter _.isString
    path = fs.path.join segments...
    fs.readFileSync path, encoding: 'utf8'

extractWords = (dom) ->
    dom('h1,h2,h3,p')
        .map -> dom(this).text()
        .get()
        .join ' '
        .replace /[^\w]/g, ' '
        .split ' '
        .map (str) -> str.toLowerCase()
            
extract = ($) ->
    words = extractWords $

    lastLine = $('p').last().text()
    metadata =
        meats: _.intersection meats, words
        protein: _.intersection protein, words
        vegetarian: (_.str.contains lastLine, 'vegetarian') or protein.length > 0
        vegan: _.str.contains lastLine, 'vegan'
        name: $('h1').text() or null

processCategory = (category) ->
    console.log "Figuring out the #{category} situation."

    root = fs.path.join 'tacofancy', category
    paths = fs.readdirSync root
        .filter (path) ->
            (fs.path.extname path) is '.md'
        .filter (path) -> not _.str.contains path, 'README'

    slugs = paths
        .map (path) -> path.slice 0, -3
        .map _.str.dasherize

    markdown = paths
        .map _.partial read, root

    # TODO: rewrite links
    html = markdown
        .map behaved toHTML

    metadata = html
        .map behaved cheerio.load
        .map extract

    data = _.zip slugs, markdown, html, metadata
        .map ([slug, markdown, html, metadata]) ->
            _.extend metadata, 
                {slug, markdown, html, category: categories[category]}

    data

processRecipes = (callback) ->
    recipes = (_.values categories).map processCategory
    categorizedRecipes = _.object _.zip (_.keys categories), recipes
    callback null, categorizedRecipes

saveRecipes = (recipes, callback) ->
    serialized = JSON.stringify recipes, undefined, 2
    fs.writeFile 'data/all.json', serialized, 
        {encoding: 'utf8'}, callback

async.waterfall [download, setup, processRecipes, saveRecipes], (err) ->
    console.log 'Robot-readable recipes ready!'

    if process.argv[2] isnt 'local'
        exec 'zip, sync ./data to s3'
