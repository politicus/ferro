#TODO check file-global vars not covering local

f.CONTEXTS =
  TAB: 0
  EXTENSION: 1
  APP: 2
  SESSION: 3
  TEXT: 4
  MAIN: 5

# todo reorder for correct default
f.COMMANDS =
  duplicate:
    desc: 'Duplicate tab.'
    context: [f.CONTEXTS.TAB, f.CONTEXTS.MAIN]
    fn: (tab) ->
      chrome.tabs.create _.copy(tab, 'windowId', 'index', 'url')
  reload_all_tabs:
    desc: 'Reload every tab in every window.'
    context: f.CONTEXTS.MAIN
    fn: (x) ->
      chrome.windows.getAll { populate: true }, (wins) ->
        reload_window win for win in wins
  reload_all_tabs_in_window:
    desc: 'Reload every tab in this window.'
    context: f.CONTEXTS.MAIN
    fn: (x) ->
      chrome.windows.getCurrent (win) ->
        reload_window win
  search_history:
    desc: 'Search through your history.'
    context: f.CONTEXTS.TEXT
    fn: (text) ->
      f.open 'chrome://history/#q=' + text + '&p=0'
  extract:
    desc: "Extract tabs that match the given text or the given tab's domain into a new window."
    context: [f.CONTEXTS.TEXT, f.CONTEXTS.MAIN, f.CONTEXTS.TAB]
    fn: (text) ->
      apply_to_matching_tabs text, (tabs) ->
        chrome.windows.create {
          focused: true
          tabId: tabs[0].id
        }, (win) =>
          for i in [1..tabs.length]
            chrome.tabs.move tabs[i].id, {
              windowId: win.id
              index: 0
            }
  close:
    desc: "Close tabs that match the given text or the given tab's domain."
    context: [f.CONTEXTS.TEXT, f.CONTEXTS.MAIN, f.CONTEXTS.TAB]
    fn: (text) ->
      apply_to_matching_tabs text, (tabs) ->
        chrome.tabs.remove tab.id for tab in tabs
  kill:
    desc: "Kill tabs that match the given text or the given tab's domain."
    context: [f.CONTEXTS.TEXT, f.CONTEXTS.MAIN, f.CONTEXTS.TAB]
    fn: (text) ->
      apply_to_matching_tabs text, (tabs) ->
        kill tab.id for tab in tabs
  kill_all:
    desc: 'Kill all tabs.'
    context: f.CONTEXTS.MAIN
    fn: (x) ->
      chrome.windows.getAll { populate: true }, (wins) ->
        (kill tab.id for tab in win.tabs) for win in wins
  pin:
    desc: 'Pin tab.'
    context: [f.CONTEXTS.TAB, f.CONTEXTS.MAIN]
    fn: (tab) ->
      chrome.tabs.update tab.id, {pinned: true}
  unpin:
    desc: 'Unpin tab.'
    context: [f.CONTEXTS.TAB, f.CONTEXTS.MAIN]
    fn: (tab) ->
      chrome.tabs.update tab.id, {pinned: false}
  select:
    desc: 'Select tab.'
    context: f.CONTEXTS.TAB
    fn: (tab) ->
      chrome.tabs.update tab.id, {selected: true}
  enable:
    context: [f.CONTEXTS.EXTENSION, f.CONTEXTS.APP]
    fn: (ext) ->
      chrome.management.setEnabled ext.id, true
  disable:
    context: [f.CONTEXTS.EXTENSION, f.CONTEXTS.APP]
    fn: (ext) ->
      chrome.management.setEnabled ext.id, false
  options:
    desc: 'Open the options page.'
    context: [f.CONTEXTS.EXTENSION, f.CONTEXTS.APP]
    fn: (ext) ->
      f.open ext.optionsUrl
  describe:
    context: [f.CONTEXTS.EXTENSION, f.CONTEXTS.APP]
    fn: (ext) ->
      f.display ext.description + ' -- Version: ' + ext.version
  homepage:
    context: [f.CONTEXTS.EXTENSION, f.CONTEXTS.APP]
    fn: (ext) ->
      f.open ext.homepageUrl
  launch:
    context: f.CONTEXTS.APP
    fn: (app) ->
      chrome.management.launchApp app.id
  uninstall:
    context: [f.CONTEXTS.EXTENSION, f.CONTEXTS.APP]
    fn: (ext) ->
      chrome.management.uninstall ext.id
  save:
    desc: 'Save the current window with the name given.'
    context: f.CONTEXTS.TEXT
    fn: (name) ->
      chrome.windows.getCurrent (win) =>
        add_session name, [prepare win]
  save_all:
    desc: 'Save all open windows with the name given.'
    context: f.CONTEXTS.TEXT
    fn: (name) ->
      chrome.windows.getAll {populate: true}, (wins) =>
        add_session name, prepare win for win in wins
  open:
    desc: 'Open saved session.'
    context: f.CONTEXTS.SESSION
    fn: (session) ->
      open_session session
  remove:
    desc: 'Delete saved session.'
    context: f.CONTEXTS.SESSION
    fn: (session) ->
      chrome.extension.sendRequest {
        action: 'delete'
        value: session.name
      }, ->

f.COMMAND_NAMES = []

for x, i of f.CONTEXTS
  f.COMMAND_NAMES[i] = []

for name, cmd of f.COMMANDS
  context = cmd.context
  context = [context] unless context instanceof Array
  f.COMMAND_NAMES[c].concat {name: name, cmd: cmd} for c in context

prepare = (win) ->
  _.extend _.copy(win, 'left', 'top', 'width', 'height', 'focused'),
    url: _(win.tabs).pluck 'url'

apply_to_matching_tabs = (text, fn) ->
  if text.url
    tab = text
    if _(tab.url).startsWith 'chrome' or _(tab.url).startsWith 'about'
      apply_to_regex_tabs /^(chrome|about)/, fn
    else
      http = '^https*://'
      domain = tab.url.match(new RegExp(http + '(.*\..{2,4}/)', 'i'))[1]
      apply_to_regex_tabs new RegExp(http + domain, 'i') if domain, fn
  else
    apply_to_regex_tabs new RegExp(text, 'i'), fn

apply_to_regex_tabs = (regex, fn) ->
  tabs = get_tabs regex
  chrome.windows.getAll {populate: true}, (wins) =>
    tabs = tab for tab in _.flatten(win.tabs for win in wins) when regex.test tab.url
    fn tabs
  
open_session = (session) ->
  for win in session.wins
    chrome.windows.create win

add_session = (name, wins) ->
  chrome.extension.sendRequest {
    action: 'create'
    value:
      name: name
      wins: wins
  }, (response) ->

reload_window = (win) ->
  chrome.tabs.update(tab.id, {url: tab.url}) for tab in win.tabs

kill = (id) ->
  chrome.tabs.update id, {url: 'about:kill'}