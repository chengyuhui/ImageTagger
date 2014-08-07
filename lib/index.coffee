program = require 'commander'
packageinf = require '../package.json'
fs = require 'fs'
_ = require 'lodash'

config = {}
cliconfig = {}
if fs.existsSync('./imgtagger.conf.js')
  console.log 'Config file exists, loading...'
  try
    config = require './imgtagger.conf.js'
  catch e
    console.error 'Error while parsing imgtagger.conf.js: ' + e
    process.exit(1)


program.version(packageinf.version)
.option('-d, --dry','No renaming, just output',->cliconfig.dry = true)
.option('-m, --regex <regex>','Regular expression for matching image id.',(ex)->
  try
    regex = new RegExp(ex)
    cliconfig.match = (fname)->
      result = fname.match regex
      return false if _.isNull result
      return _.last result
  catch e
    console.error e
    process.exit 1
)
.option('-t, --template <string>','Underscore template for formatting output filename
                          (extension will be added automatically)',(template)->
  cliconfig.template = _.template(template,null)
)
.option('-i, --include <mime>','MIME type to include.',(type)->
  cliconfig.mime = [] if not cliconfig.mime?
  cliconfig.mime.push type
)
.option('-c, --config <filename>','Specify config file.',(conf)->
  try
    config = require conf
  catch e
    console.error 'Error while loading config file: ' + e
    process.exit(1)
)

program
.command('pixiv')
.description('Tag images from pixiv.')
.action (env)->
  config = _.extend config,cliconfig
  require('./pixiv')(env,config)

program.parse process.argv