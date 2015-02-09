var PixivAPI, rp,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

rp = require('request-promise');

PixivAPI = (function() {
  function PixivAPI() {
    this._PAPI_Request = __bind(this._PAPI_Request, this);
  }

  PixivAPI.prototype.login = function(username, password) {
    var form, url;
    url = 'https://oauth.secure.pixiv.net/auth/token';
    form = {
      username: username,
      password: password,
      grant_type: 'password',
      client_id: 'BVO2E8vAAikgUBW8FYpi6amXOjQj',
      client_secret: 'LI1WsFUDrrquaINOdarrJclCrkTtc3eojCOswlog'
    };
    return rp({
      url: url,
      method: 'POST',
      form: form,
      resolveWithFullResponse: true
    }).then((function(_this) {
      return function(result) {
        var token;
        token = JSON.parse(result.body).response;
        _this.accessToken = token.access_token;
        _this.userID = token.user.id;
        _this.session = result.headers['set-cookie'][0].split('; ')[0].split('=')[1];
        return token;
      };
    })(this))["catch"](function(rep) {
      throw new Error("Login failed (" + rep.statusCode + "), check username/password.");
    });
  };

  PixivAPI.prototype._PAPI_Request = function(method, path, params) {
    var options, url;
    method = method.toUpperCase();
    url = 'https://public-api.secure.pixiv.net' + path;
    options = {
      url: url,
      method: method,
      headers: {
        Cookie: 'PHPSESSID=' + this.session
      },
      auth: {
        bearer: this.accessToken
      }
    };
    if (method === 'POST') {
      options.form = params;
    }
    if (method === 'GET') {
      options.qs = params;
    }
    return rp(options).then(JSON.parse).then(function(body) {
      if (body.status === !'success') {
        throw new Error("Request failed: " + body.status);
      }
      return body;
    });
  };

  PixivAPI.prototype.users = function(authorID) {
    return this._PAPI_Request('GET', "/v1/users/" + authorID + ".json", {
      profile_image_sizes: 'px_170x170,px_50x50',
      image_sizes: ['px_128x128', 'small', 'medium', 'large', 'px_480mw'].join(','),
      include_stats: 1,
      include_profile: 1,
      include_workspace: 1,
      include_contacts: 1
    }).get('response').get(0);
  };

  PixivAPI.prototype.works = function(workID) {
    return this._PAPI_Request('GET', "/v1/works/" + workID + ".json", {
      profile_image_sizes: 'px_170x170,px_50x50',
      image_sizes: ['px_128x128', 'small', 'medium', 'large', 'px_480mw'].join(','),
      include_stats: 'true'
    }).get('response').get(0);
  };

  return PixivAPI;

})();

module.exports = PixivAPI;
