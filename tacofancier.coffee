_ = require 'underscore'
_.str = require 'underscore.string'
fs = require 'fs'
fs.path = require 'path'
fs.mkdirp = require 'mkdirp'
{exec} = require 'child_process'
async = require 'async'
request = require 'request'
cheerio = require 'cheerio'
{markdown} = require 'markdown'
toHTML = _.bind markdown.toHTML, markdown
AWS = require 'aws-sdk'

context = if process.argv[2] is 'local' then 'local' else 'remote'

if context is 'local'
    env = process.env
else
    worker = require 'ironworker-helper'
    env = worker.config

AWS.config.update {
    accessKeyId: env.AWS_ACCESS_KEY_ID
    secretAccessKey: env.AWS_SECRET_ACCESS_KEY
    region: 'us-east-1'
    }

s3 = new AWS.S3()

categories =
    base_layers: 'layers'
    full_tacos: 'tacos'
    like_tacos: 'more'
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

github = 'https://api.github.com/repos/sinker/tacofancy/commits?'
getContributors = (path, callback) ->
    options =
        path: path
        client_id: process.env.GITHUB_CLIENT_ID
        client_secret: process.env.GITHUB_CLIENT_SECRET

    # GitHub doesn't like escaped querystrings, so we roll our own
    kvs = _.map options, (value, key) ->
        "#{key}=#{value}"
    qs = kvs.join '&'

    params =
        headers:
            'user-agent': 'stdbrouw/tacofancier'
        uri: github + qs
        json: yes
    request.get params, (err, res, commits) ->
        if err or res.statusCode isnt 200 then return callback err

        contributors = commits.map (commit) ->
            contributor =
                name: commit.commit.author.name
                username: commit.author?.login
        contributors = _.unique contributors, no, _.property 'username'
        author = _.last contributors

        callback null, {author, contributors}

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

processCategory = (category, callback) ->
    repoRoot = category
    fileRoot = fs.path.join 'tacofancy', category

    paths = fs.readdirSync fileRoot
        .filter (path) ->
            (fs.path.extname path) is '.md'
        .filter (path) ->
            not _.str.contains path, 'README'

    repoPaths = paths.map (path) ->
        fs.path.join repoRoot, path

    slugs = paths
        .map (path) -> path.slice 0, -3
        .map _.str.dasherize

    markup = paths
        .map _.partial read, fileRoot

    # TODO: rewrite links
    html = markup
        .map behaved toHTML

    metadata = html
        .map behaved cheerio.load
        .map extract

    async.mapSeries repoPaths, getContributors, (err, authorship) ->
        if err then return callback err

        data = _.zip paths, slugs, markup, html, metadata, authorship
            .map ([path, slug, markdown, html, metadata, authorship]) ->
                _.extend metadata, authorship, 
                    {path, slug, markdown, html, category: categories[category]}

        console.log "Figured out the #{category} situation."
        callback null, data

processRecipes = (callback) ->
    async.map (_.keys categories), processCategory, (err, recipes) ->
        if err then return callback err
        categorizedRecipes = _.object _.zip (_.values categories), recipes
        callback null, categorizedRecipes

writeRecipes = (recipes, callback) ->
    serialized = JSON.stringify recipes, undefined, 2

    if context is 'local'
        fs.writeFile 'data/all.json', serialized, {encoding: 'utf8'}, callback
    else
        params =
            Bucket: env.AWS_S3_BUCKET_NAME
            Key: 'all.json'
            Body: serialized
        s3.putObject params, callback

async.waterfall [download, setup, processRecipes, writeRecipes], (err, recipes) ->
    if err
        console.log err.message
        throw new Error err.message
    else
        console.log 'Robot-readable recipes ready!'
