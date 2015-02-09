_ = require 'lodash'
fs = require 'mz/fs'
mime = require 'mime'
path = require 'path'
log = require 'npmlog'
util = require './util'
Promise = require 'bluebird'
Queue = require 'promise-queue'

validMime = ['image/jpeg', 'image/png']

module.exports = (program,conf) ->
  dir = process.cwd()
  files = []

  fs.stat(dir)
  .then((stat) ->
    if !stat.isDirectory()
      throw new Error "#{dir} is not a directory."
    fs.readdir(dir)
  )
  .then((fileList) ->
    {Match,Is} = require('pat-mat')
    m = Match(
      #Single
      Is(/^(\d+)$/, (id) -> id: id, page: null),
      #Multi like 30594129_big_p1
      Is(/^(\d+)_big_p(\d+)$/, (w, id, page) -> id: id, page: parseInt(page)),
      #Multi like 18620929_1
      Is(/^(\d+)_(\d+)$/, (w, id, page) -> id: id, page: parseInt(page))
    )

    fileList = for n in fileList when mime.lookup(n) in validMime
      basename = path.basename(n, path.extname(n)) #Filename w/o ext.

      file = ''
      try
        file = m(basename)
      catch e
        continue
      file.ext = path.extname(n)
      file.orig = path.basename(n)
      file

    throw new Error('Nothing to do.') if fileList.length is 0

    log.info('listing', "#{fileList.length} valid file(s) found.")


    uniqID = []

    uniqID.push(file.id) for file in fileList when uniqID.indexOf(file.id) < 0

    log.info(null,"#{uniqID.length} unique ID(s) extracted.")

    files = fileList #Save it.

    PixivAPI = require('./api')

    api = new PixivAPI
    log.info(null, 'Starting log in.')
    api.login(conf.username, conf.password)
    .then(->
      log.info(null, 'Logged in.')

      Queue.configure Promise

      queue = new Queue(7, Infinity)

      makeGenerator = (id) ->
        successHandler = (info) ->
          l = "#{info.user.name} - #{info.title} (#{info.id}@#{info.user.id})"
          log.info('work',l)
          info

        rejectHandler = (err) ->
          log.error('work', "Failed to fetch ##{id}")
          throw err

        return ->
          api.works(id)
          .then(successHandler)
          .catch(rejectHandler)

      #We use settle here because we don't want unsuccessful query to crash.
      Promise.settle(queue.add(makeGenerator(id)) for id in uniqID)
    )
    .filter((result) -> result.isFulfilled())
    .map((result) -> result.value())
    .then((works) ->
      origLen = files.length
      log.info(null,'Calculating new file names...')
      files = for file in files
        for work in works
          continue if work.id.toString() != file.id
          file.workInfo = work
        continue if not file.workInfo?
        file.new = util.genFilename(file,130)
        file

      log.info(
        null,
        "Success: #{files.length}, Failed: #{origLen - files.length}"
      )

      if program.dry
        console.log("#{file.orig} -> #{file.new}") for file in files
        process.exit(0)

      Promise.settle(
        fs.rename(
          path.join(dir, file.orig), path.join(dir, file.new)
        ) for file in files
      )
    )
  )
