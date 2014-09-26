###
I want a pony: 

- use git to figure out a recipe's author and contributors
- process links to figure out recipe relationships
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

behaved = (fn) ->
    (first) ->
        fn first

download = (callback) ->
    if fs.existsSync 'tacofancy'
        callback null
    else
        exec 'make tacofancy', callback

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

async.series [download], (err) ->
    # TODO:
    # - base_layers
    # - condiments
    # - full_tacos
    # - like_tacos
    # - mixins
    # - seasonings
    # - shells
    root = 'tacofancy/base_layers'

    paths = fs.readdirSync root
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
            _.extend metadata, {slug, markdown, html}

    serialized = JSON.stringify data, undefined, 2

    fs.mkdirp.sync 'data'
    fs.writeFileSync 'data/recipes.json', serialized, encoding: 'utf8'

    console.log 'Robot-readable recipes ready!'

if process.argv[2] isnt 'local'
    exec 'zip, sync ./data to s3'
