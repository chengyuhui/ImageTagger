var log, removeLongest, renderTmpl;

log = require('npmlog');

removeLongest = function(arr) {
  var i, longestIndex, longestLen, removed, str, _i, _len;
  longestLen = 0;
  longestIndex = 0;
  for (i = _i = 0, _len = arr.length; _i < _len; i = ++_i) {
    str = arr[i];
    if (str.length > longestLen) {
      longestLen = str.length;
      longestIndex = i;
    }
  }
  removed = arr[longestIndex];
  delete arr[longestIndex];
  return removed;
};

renderTmpl = function(work) {
  return [work.user.name + " - " + work.title, " ", "(" + work.id + "@" + work.user.id + ")", "[ #" + (work.tags.join(" ")) + "]"].join("").replace(/[\|\\/:*?"<>]/g, '');
};

exports.genFilename = function(file, maxLen) {
  var removed, ret;
  ret = "";
  while (renderTmpl(file.workInfo).length > maxLen && file.workInfo.tags.length > 0) {
    removed = removeLongest(file.workInfo.tags);
    log.warn('tag', "Removing tag " + removed + " from work #" + file.id + "(" + file.workInfo.title + ").");
  }
  ret += renderTmpl(file.workInfo);
  if (file.page != null) {
    ret += " " + file.page + "P";
  }
  ret += file.ext;
  return ret;
};
