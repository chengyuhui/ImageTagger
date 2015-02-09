# Load all required Libraries.
gulp = require 'gulp'
coffeeScript = require 'coffee-script'
coffee = require 'gulp-coffee'
coffeelint = require 'gulp-coffeelint'
gutil = require 'gulp-util'

coffeePath = [
  'src/**/*.coffee'
]

gulp.task 'coffee', ->
  gulp.src coffeePath
    .pipe coffee(bare: on)
    .on 'error',gutil.log
    .pipe gulp.dest './lib/'

gulp.task 'watch', ->
  gulp.watch coffeePath, ['coffee']
