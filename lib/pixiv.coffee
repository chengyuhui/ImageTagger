_ = require 'lodash'
dive = require 'dive'
path = require 'path'
async = require 'async'
wait = require 'wait.for'
mime = require 'mime'
request = require 'superagent'
cheerio = require 'cheerio'

module.exports = (env,config)->
  defaults =
    match:(fname)->
      result = fname.match /^\d+\s*-\s*(\d+)\s*$/
      return false if _.isNull result
      return _.last result
    dry:false
    template:_.template('<%= user %> - <%= title %> (<%= work_id %>@<%= user_id %>)[<%= tags.join(" ") %>]')
    recursive:false
    mime:[
      'image/jpeg'
      'image/png'
    ]
    dir:env||process.cwd()

  config = _.extend defaults,config

  queue = async.queue((id,done)->
    err = (e)->
      _.defer done,e
    wait.launchFiber ->
      agent = request
      .get(['http://zh.pixiv.com/works/',id].join(''))
      .set('User-Agent','Mozilla/5.0 (Windows NT 6.3; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/36.0.1985.125 Safari/537.36')
      res = null
      try
        res = wait.forMethod agent,'end'
      catch e
        return err(e)

      if res.statusCode is not 200
        return err(res.statusCode)

      $ = cheerio.load(res.text)
      info = {
        title:$('h1.title').text()
        work_id:id
      }

      user = $('.author-summary').children('.u-name')
      info.user_id = _.last user.attr('href').split('/')
      info.user = user.children().text()

      info.tags = tags = []

      $('.added-tags').children().each (index,elem)->
        tags.push $(@).children('a').text().trim()

      wait.for _.partialRight(setTimeout,1000)

      _.defer done,null,info
  ,1)

  dive(config.dir,{recursive:config.recursive},(err,name)->
    if err
      console.log err
      return
    return if not mime.lookup(name) in config.mime
    id = config.match path.basename(name,path.extname(name))
    return if !id
    queue.push id,(err,info)->
      return console.error 'ERR:' + err if err
      console.log path.basename(name,path.extname(name)) + ' -> ' + config.template(info)

      #queue.kill()
  )

