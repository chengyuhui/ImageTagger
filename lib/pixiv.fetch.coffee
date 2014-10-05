request = require 'superagent'
_ = require 'lodash'
Q = require 'q'
cheerio = require 'cheerio'

module.exports = (id)->
  agent = request
  .get(['http://www.pixiv.net/member_illust.php?mode=medium&illust_id=',id].join(''))
  .set('User-Agent','Mozilla/5.0 (Windows NT 6.3; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/36.0.1985.125 Safari/537.36')

  Q.ninvoke(agent,'end')
  .then((rep)->
    unless rep.statusCode is 200
      throw new Error("Server response: #{rep.statusCode}.")

    $ = cheerio.load(rep.text)
    info = {
      work_id:id
    }
    try
      userinf = $('.userdata')
      info.title = userinf.children('.title').text()
      user = userinf.children('.name').children('a')
      info.user_id = _.last user.attr('href').split('?id=')
      info.user = user.text()

      info.tags = tags = []

      $('#tag_area').find('.tag').each (index,elem)->
        tags.push $(@).children('a.text').text().trim()

    catch e
      console.dir e
      throw new Error("Invalid response: #{e}.")

    return info
  )