log = require 'npmlog'

# Private: Remove the longest string in the given array.
#
# arr - The input {Array}.
#
# Returns {String} that is removed.
removeLongest = (arr) ->
  longestLen = 0
  longestIndex = 0
  for str,i in arr
    if str.length > longestLen
      longestLen = str.length
      longestIndex = i

  removed = arr[longestIndex]
  delete arr[longestIndex]
  removed

renderTmpl = (work) ->
  [
    "#{work.user.name} - #{work.title}"
    " "
    "(#{work.id}@#{work.user.id})"
    "[ ##{work.tags.join(" ")}]"
  ].join("").replace(/[\|\\/:*?"<>]/g, '')

exports.genFilename = (file, maxLen) ->
  ret = ""
  while renderTmpl(file.workInfo).length > maxLen and
  file.workInfo.tags.length > 0
    removed = removeLongest(file.workInfo.tags)
    log.warn(
      'tag',
      "Removing tag #{removed} from work ##{file.id}(#{file.workInfo.title})."
    )
  ret += renderTmpl(file.workInfo)
  ret += " #{file.page}P" if file.page?
  ret += file.ext
  ret
