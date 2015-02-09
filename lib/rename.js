var Promise, Queue, fs, log, mime, path, util, validMime, _,
  __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

_ = require('lodash');

fs = require('mz/fs');

mime = require('mime');

path = require('path');

log = require('npmlog');

util = require('./util');

Promise = require('bluebird');

Queue = require('promise-queue');

validMime = ['image/jpeg', 'image/png'];

module.exports = function(program, conf) {
  var dir, files;
  dir = process.cwd();
  files = [];
  return fs.stat(dir).then(function(stat) {
    if (!stat.isDirectory()) {
      throw new Error(dir + " is not a directory.");
    }
    return fs.readdir(dir);
  }).then(function(fileList) {
    var Is, Match, PixivAPI, api, basename, e, file, m, n, uniqID, _i, _len, _ref;
    _ref = require('pat-mat'), Match = _ref.Match, Is = _ref.Is;
    m = Match(Is(/^(\d+)$/, function(id) {
      return {
        id: id,
        page: null
      };
    }), Is(/^(\d+)_big_p(\d+)$/, function(w, id, page) {
      return {
        id: id,
        page: parseInt(page)
      };
    }), Is(/^(\d+)_(\d+)$/, function(w, id, page) {
      return {
        id: id,
        page: parseInt(page)
      };
    }));
    fileList = (function() {
      var _i, _len, _ref1, _results;
      _results = [];
      for (_i = 0, _len = fileList.length; _i < _len; _i++) {
        n = fileList[_i];
        if (!(_ref1 = mime.lookup(n), __indexOf.call(validMime, _ref1) >= 0)) {
          continue;
        }
        basename = path.basename(n, path.extname(n));
        file = '';
        try {
          file = m(basename);
        } catch (_error) {
          e = _error;
          continue;
        }
        file.ext = path.extname(n);
        file.orig = path.basename(n);
        _results.push(file);
      }
      return _results;
    })();
    if (fileList.length === 0) {
      throw new Error('Nothing to do.');
    }
    log.info('listing', fileList.length + " valid file(s) found.");
    uniqID = [];
    for (_i = 0, _len = fileList.length; _i < _len; _i++) {
      file = fileList[_i];
      if (uniqID.indexOf(file.id) < 0) {
        uniqID.push(file.id);
      }
    }
    log.info(null, uniqID.length + " unique ID(s) extracted.");
    files = fileList;
    PixivAPI = require('./api');
    api = new PixivAPI;
    log.info(null, 'Starting log in.');
    return api.login(conf.username, conf.password).then(function() {
      var id, makeGenerator, queue;
      log.info(null, 'Logged in.');
      Queue.configure(Promise);
      queue = new Queue(7, Infinity);
      makeGenerator = function(id) {
        var rejectHandler, successHandler;
        successHandler = function(info) {
          var l;
          l = info.user.name + " - " + info.title + " (" + info.id + "@" + info.user.id + ")";
          log.info('work', l);
          return info;
        };
        rejectHandler = function(err) {
          log.error('work', "Failed to fetch #" + id);
          throw err;
        };
        return function() {
          return api.works(id).then(successHandler)["catch"](rejectHandler);
        };
      };
      return Promise.settle((function() {
        var _j, _len1, _results;
        _results = [];
        for (_j = 0, _len1 = uniqID.length; _j < _len1; _j++) {
          id = uniqID[_j];
          _results.push(queue.add(makeGenerator(id)));
        }
        return _results;
      })());
    }).filter(function(result) {
      return result.isFulfilled();
    }).map(function(result) {
      return result.value();
    }).then(function(works) {
      var origLen, work, _j, _len1;
      origLen = files.length;
      log.info(null, 'Calculating new file names...');
      files = (function() {
        var _j, _k, _len1, _len2, _results;
        _results = [];
        for (_j = 0, _len1 = files.length; _j < _len1; _j++) {
          file = files[_j];
          for (_k = 0, _len2 = works.length; _k < _len2; _k++) {
            work = works[_k];
            if (work.id.toString() !== file.id) {
              continue;
            }
            file.workInfo = work;
          }
          if (file.workInfo == null) {
            continue;
          }
          file["new"] = util.genFilename(file, 130);
          _results.push(file);
        }
        return _results;
      })();
      log.info(null, "Success: " + files.length + ", Failed: " + (origLen - files.length));
      if (program.dry) {
        for (_j = 0, _len1 = files.length; _j < _len1; _j++) {
          file = files[_j];
          console.log(file.orig + " -> " + file["new"]);
        }
        process.exit(0);
      }
      return Promise.settle((function() {
        var _k, _len2, _results;
        _results = [];
        for (_k = 0, _len2 = files.length; _k < _len2; _k++) {
          file = files[_k];
          _results.push(fs.rename(path.join(dir, file.orig), path.join(dir, file["new"])));
        }
        return _results;
      })());
    });
  });
};
