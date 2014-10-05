_ = require 'lodash'
path = require 'path'
fs = require 'fs'
mime = require 'mime'
throat = require 'throat'
Q = require 'q'

valid_type = [
  'image/jpeg'
  'image/png'
]

limitConcurrency = (promiseFactory,limit)->
  fn = throat(limit, promiseFactory)
  return ->
    Q(fn.apply(this, arguments))

removeLongest = (arr)->
  longestLen = 0
  longestIndex = 0
  for v,i in arr
    continue if not v?
    if v.length > longestLen
      longestIndex = i
      longestLen = v.length

  removed = arr[longestIndex]
  delete arr[longestIndex]
  return removed

matchFilename = (fname)->
  basename = path.basename(fname,path.extname(fname))
  result = basename.match /^(\d+)$/
  return false if _.isNull result
  return {id:_.last(result),ext:path.extname(fname)}

tmpl = _.template('<%= user %> - <%= title %> (<%= work_id %>@<%= user_id %>)[ #<%= tags.join(" ") %> ]')

module.exports = (dir,prog,log)->
  filelist = []
  try
    stat = fs.statSync(dir)
    if not stat.isDirectory()
      log.error(null,"#{dir} is not a directory.")
      process.exit(1)
    filelist = fs.readdirSync(dir)
  catch e
    log.error(null,"Listing files failed: #{e.message}")
    process.exit()

  filelist = _.compact(filelist.filter((n)->mime.lookup(n) in valid_type).map(matchFilename))

  if filelist.length is 0
    log.info(null,'Nothing to do.')
    process.exit()

  log.info(null,"#{filelist.length} valid file(s) found.")

  fetch = require './pixiv.fetch'

  log.info(null,"Processing...")

  cmd_tmpl = _.template('<%= user %> - <%= title %> (<%= work_id %>@<%= user_id %>)')



  Q.allSettled(filelist.map(limitConcurrency((file)->
    id = file.id
    fetch(id)
    .then((work)->
      log.info('work',cmd_tmpl(work))
      while tmpl(work).length > 100 and work.tags.length != 0
        log.warn('tags',"Removing tag #{removeLongest(work.tags)} from work ##{id}.")

      work.ext = file.ext
      return work
    ,(err)->
      log.error('work',"Failed to fetch ##{id}: #{err.message}")
      throw err
    )
  ,prog.jobs)))

  .then((results)->
    fail_count = 0
    success_count = 0
    works = _.pluck(results.filter((r)->
      if r.state is "fulfilled"
        return true
      else
        fail_count += 1
        return false
    ),"value")
    if prog.dry
      success_count = works.length
      log.info("dry-run","Complete. Success: #{success_count}, Failed: #{fail_count}")
      return

    log.info(null,"Renaming...")
    rename = Q.nbind(fs.rename)

    rename_promise = works.map((w)->
      rename(path.join(dir,w.work_id + w.ext),path.join(dir,tmpl(w).replace(/[\|\\/:*?"<>]/g, '') + w.ext))
      .catch((e)->
        log.error("rename","Failed to rename ##{w.work_id}: #{e.message}")
        throw e
      )
    )

    Q.allSettled(rename_promise)
    .then((results)->
      results.forEach((r)->
        if r.state is "fulfilled"
          success_count += 1
        else
          fail_count += 1
      )
    )
    .done(->
      log.info("Nya","Complete. Success: #{success_count}, Failed: #{fail_count}")
    )

  )






