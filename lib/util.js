var request = require('co-request'),
    co = require('co'),
    cheerio = require('cheerio'),
    _ = require('lodash'),
    thread = require('co-thread'),
    log = require('npmlog'),
    mime = require('mime'),
    path = require("path");

var cmd_tmpl = _.template('<%= user %> - <%= title %> (<%= work_id %>@<%= user_id %>)');

/**
 * Fetch Pixiv work information by ID.
 * @param {string} id - The ID of work.
 * @returns {object}
 */
export function fetchById(id) {
    return co(function*(){
        var url = ['http://www.pixiv.net/member_illust.php?mode=medium&illust_id=', id].join('');
        var res = yield request(url,{
            headers:{
                'User-Agent':['Mozilla/5.0 (Windows NT 6.3; WOW64) AppleWebKit/537.36 ',
                    '(KHTML, like Gecko) Chrome/36.0.1985.125 Safari/537.36'].join('')
            }
        });

        if (res.statusCode !== 200){
            throw new Error("Server response: " + res.statusCode + ".");
        }

        var $ = cheerio.load(res.body),
            info = {
                work_id: id
            };
        try {
            var tags,userinf,user;
            userinf = $('.userdata');
            info.title = userinf.children('.title').text();
            user = userinf.children('.name').children('a');
            info.user_id = _.last(user.attr('href').split('?id='));
            info.user = user.text();
            info.tags = tags = [];
            $('#tag_area').find('.tag').each(function(index, elem) {
                return tags.push($(this).children('a.text').text().trim());
            });
        } catch (e) {
            throw new Error("Invalid response: " + e + ".");
        }
        log.info('work',cmd_tmpl(info));
        return info;
    }).catch(function (e) {
        log.error('work',"Failed to fetch #%d: %s",id,e.message);
        throw e;
    });
}

/**
 * Remove the longest string in arr.
 *
 * @param {Array<String>} arr
 * @returns {Array}
 */
export function removeLongest(arr) {
    var i, longestIndex, longestLen, removed, v, _i, _len;
    longestLen = 0;
    longestIndex = 0;
    for (i = _i = 0, _len = arr.length; _i < _len; i = ++_i) {
        v = arr[i];
        if (v === null) {
            continue;
        }
        if (v.length > longestLen) {
            longestIndex = i;
            longestLen = v.length;
        }
    }
    removed = arr[longestIndex];
    delete arr[longestIndex];
    return removed;
}

/**
 * Original: co-parallel by TJ.
 * @param thunks
 * @param n
 * @returns {Array}
 */
export function *parallel(thunks, n){
    n = Math.min(n || 5, thunks.length);
    var ret = [];
    var index = 0;

    function *next() {
        var i = index++;
        try {
            ret[i] = yield thunks[i];
        } catch (e) {
            ret[i] = null;
        }

        if (index < thunks.length) yield next;
    }

    yield thread(next, n);

    return ret;
}

export function genFilename(w,dir,tmpl){
    var from = path.join(dir,w.orig),
        to = path.join(dir,tmpl(w.info).replace(/[\|\\/:*?"<>]/g, ''));
    if (!_.isNull(w.page)){
        to += [' ',w.page,'P'].join('');
    }
    var ext = mime.extension(w.type);
    if (ext === "jpeg") {
        ext = "jpg";
    }
    to += '.' + ext;
    return to;
}