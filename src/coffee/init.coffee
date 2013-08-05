DEBUG = false

d = (ss...) ->
  if DEBUG
    for s in ss
      console.log s 

tab_open = (url) ->
  chrome.tabs.create {url}

sentence_case = (s) ->
  ret = s[0].toUpperCase() + s[1..-1].toLowerCase()
  while (i = ret.indexOf '_') > 0
    ret = ret[0..i-1] + ' ' + s[i+1].toUpperCase() + s[i+2..-1].toLowerCase()
  ret

display_message = (msg) ->
  $('body').empty()
  $('body').html msg

track = (args...) ->
  args.unshift '_trackEvent'
  _gaq.push args
