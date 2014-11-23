/*global System */
var log = require('npmlog'),
    co = require('co'),
    fs = require('mz/fs'),
    _ = require('lodash'),
    mime = require('mime'),
    path = require("path");

export function run (dir,program) {
    var tmpl = _.template('<%= user %> - <%= title %> (<%= work_id %>@<%= user_id %>)[ #<%= tags.join(" ") %> ]')
    co(function*(){
        var filelist;
        try{
            let stat = yield fs.stat(dir);
            if (!stat.isDirectory()) {
                log.error(null, dir + " is not a directory.");
                process.exit(1);
            }
            filelist = fs.readdirSync(dir);
        }catch(e){
            log.error(null, "Listing files failed: " + e.message);
            process.exit(1);
        }
        var m;
        {
            let {Match,Is} = require('pat-mat');
            m = Match(
                //single
                Is(/^(\d+)$/, function (id) {return {id:id,page:null};}),
                //multi like 30594129_big_p1
                Is(/^(\d+)_big_p(\d+)$/, function (w, id, page) {return {id:id,page:parseInt(page)}; }),
                //multi like 18620929_1
                Is(/^(\d+)_(\d+)$/, function (w, id, page) {return {id:id,page:parseInt(page)};})
            );
        }

        filelist = _.compact(filelist.filter(function (n) {
            return ['image/jpeg','image/png'].indexOf(mime.lookup(n)) >= 0;
        }).map(function (n) {
            var basename = path.basename(n, path.extname(n));
            var file;
            try {
                file = m(basename);
            } catch (e) {
                //Ignore if not matched
                return false;
            }
            file.type = mime.lookup(n);
            file.orig = path.basename(n);
            return file;
        }));

        if(filelist.length === 0){
            log.info(null,'Nothing to do.');
            process.exit();
        }

        log.info(null,"%d valid file(s) found.",filelist.length);

        //Extract unique IDs
        var ids = [];
        for (var file of filelist) {
            if(ids.indexOf(file.id) < 0){
                ids.push(file.id);
            }
        }

        log.info(null,"%d unique ID(s) extracted.",ids.length);

        var util = yield System.import('util'),
            info;

        {
            let f = function*(id){
                return yield util.fetchById(id);
            };
            info = yield util.parallel(ids.map(f),program.jobs);
        }
        var info_hash = {},err_count = 0
        for (var inf of info) {
            if(_.isNull(inf)){
                continue;
            }
            while (tmpl(inf).length + 4 >=100 && inf.tags.length > 0) {
                log.warn('tags', "Removing tag %s from work #%s(%s).",util.removeLongest(inf.tags),inf.work_id,inf.title);
            }
            info_hash[inf.work_id] = inf;
        }

        var files = _.compact(filelist.map(function (f) {
            if (typeof info_hash[f.id] === "undefined"){
                err_count += 1;
                return null;
            }
            f.info = info_hash[f.id];
            return f;
        }))

        if(program.dry){
            log.info("dry-run","Complete. Success: %d, Failed: %d",files.length,err_count);
            return;
        }

        log.info(null,"Renaming...");
        {
            let r = function*(w){
                var from = path.join(dir,w.orig),
                    to = util.genFilename(w,dir,tmpl);
                return yield fs.rename(from,to);
            };
            yield util.parallel(files.map(r));
        }
        log.info("FIN","Complete. Success: %d, Failed: %d",files.length,err_count);
    }).catch(function (e) {
        console.log(e);
    });
}
