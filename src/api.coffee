rp = require 'request-promise'

class PixivAPI
  login: (username, password) ->
    url = 'https://oauth.secure.pixiv.net/auth/token'
    form = {
      username
      password
      grant_type: 'password'
      client_id: 'BVO2E8vAAikgUBW8FYpi6amXOjQj'
      client_secret: 'LI1WsFUDrrquaINOdarrJclCrkTtc3eojCOswlog'
    }

    rp({
      url
      method: 'POST'
      form
      resolveWithFullResponse: true
    })
    .then((result)=>
      token = JSON.parse(result.body).response
      @accessToken = token.access_token
      @userID = token.user.id
      @session = result.headers['set-cookie'][0].split('; ')[0].split('=')[1]
      return token
    )
    .catch((rep) ->
      throw new Error("Login failed (#{rep.statusCode}), check username/password.")
    )

  _PAPI_Request: (method, path, params) =>
    method = method.toUpperCase()
    url = 'https://public-api.secure.pixiv.net' + path
    options = {
      url
      method
      headers:
        Cookie: 'PHPSESSID=' + @session
      auth:
        bearer: @accessToken
    }
    options.form = params if method is 'POST'
    options.qs = params if method is 'GET'

    rp(options)
    .then(JSON.parse)
    .then((body) ->
      if body.status is not 'success'
        throw new Error("Request failed: #{body.status}")
      return body
    )

  users: (authorID) ->
    @_PAPI_Request('GET', "/v1/users/#{authorID}.json", {
      profile_image_sizes: 'px_170x170,px_50x50'
      image_sizes: [
        'px_128x128'
        'small'
        'medium'
        'large'
        'px_480mw'
      ].join(',')
      include_stats: 1
      include_profile: 1
      include_workspace: 1
      include_contacts: 1
    }).get('response').get(0)

  works: (workID) ->
    @_PAPI_Request('GET',"/v1/works/#{workID}.json",{
      profile_image_sizes: 'px_170x170,px_50x50'
      image_sizes: [
        'px_128x128'
        'small'
        'medium'
        'large'
        'px_480mw'
      ].join(',')
      include_stats: 'true'
    }).get('response').get(0)

module.exports = PixivAPI
