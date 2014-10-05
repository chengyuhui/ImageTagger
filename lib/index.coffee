program = require 'commander'
packageinf = require '../package.json'
log = require 'npmlog'
_ = require 'lodash'

log.info('version',packageinf.version)

checkArgs = ->
  program.dry = !!program.dry
  jobs = Number(program.jobs)
  if _.isNaN(jobs) or jobs < 1 or ("#{parseInt(program.jobs)}" != program.jobs)
    log.error('args',"Invalid concurrency: #{program.jobs}")
    process.exit(1)



program.version(packageinf.version)
.option('-d, --dry','No renaming, just output. ',false)
.option('-j, --jobs [limit]','Concurrency',"5")

program.command('tag [dir]')
.description('Tag images from pixiv.')
.action (env)->
  checkArgs()
  dir = env || process.cwd()
  require('./pixiv.comm')(dir,program,log)

program.parse process.argv