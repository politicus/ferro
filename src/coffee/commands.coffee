#TODO check file-global vars not covering local or getting overwritten

CONTEXTS = # tied to DEFAULTS
  TAB: 0
  EXTENSION: 1
  APP: 2
  SESSION: 3
  TEXT: 4
  SPECIAL: 5
  BOOKMARK: 6
  MAIN: 7
  COMMAND: 8

# don't add commands that have keyboard shortcuts, like close tab, close window, and create bookmark
 COMMANDS =
  duplicate:
    desc: 'Duplicate tab'
    context: [CONTEXTS.TAB, CONTEXTS.MAIN]
    fn: (tab) ->
      chrome.tabs.create _.copy(tab, 'windowId', 'index', 'url')
  reload_all_tabs:
    desc: 'Reload every tab in every window'
    context: CONTEXTS.MAIN
    fn: (x) ->
      chrome.windows.getAll { populate: true }, (wins) ->
        reload_window win for win in wins
  reload_all_tabs_in_window:
    desc: 'Reload every tab in this window'
    context: CONTEXTS.MAIN
    fn: (x) ->
      chrome.windows.getCurrent (win) ->
        reload_window win
  search_history:
    desc: 'Search through your history for the given text'
    context: CONTEXTS.TEXT
    fn: (text) ->
      tab_open 'chrome://history/#q=' + text + '&p=0'
  extract:
    desc: "Extract tabs that match the given text or the given tab's domain into a new window"
    context: [CONTEXTS.TEXT, CONTEXTS.MAIN, CONTEXTS.TAB]
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
    desc: "Close tabs that match the given text or the given tab's domain"
    context: [CONTEXTS.TEXT, CONTEXTS.MAIN, CONTEXTS.TAB]
    fn: (text) ->
      apply_to_matching_tabs text, (tabs) ->
        chrome.tabs.remove tab.id for tab in tabs
  kill:
    desc: "Kill tabs that match the given text or the given tab's domain"
    context: [CONTEXTS.TEXT, CONTEXTS.MAIN, CONTEXTS.TAB]
    fn: (text) ->
      apply_to_matching_tabs text, (tabs) ->
        kill tab.id for tab in tabs
  kill_all:
    desc: 'Kill all tabs'
    context: CONTEXTS.MAIN
    fn: (x) ->
      chrome.windows.getAll { populate: true }, (wins) ->
        (kill tab.id for tab in win.tabs) for win in wins
  pin:
    desc: 'Pin tab'
    context: [CONTEXTS.TAB, CONTEXTS.MAIN]
    fn: (tab) ->
      chrome.tabs.update tab.id, {pinned: true}
  unpin:
    desc: 'Unpin tab'
    context: [CONTEXTS.TAB, CONTEXTS.MAIN]
    fn: (tab) ->
      chrome.tabs.update tab.id, {pinned: false}
  select:
    desc: 'Select tab'
    context: CONTEXTS.TAB
    fn: (tab) ->
      chrome.tabs.update tab.id, {selected: true}
  enable:
    desc: 'Enable extension or app'
    context: [CONTEXTS.EXTENSION, CONTEXTS.APP]
    fn: (ext) ->
      chrome.management.setEnabled ext.id, true
  disable:
    desc: 'Disable extension or app'
    context: [CONTEXTS.EXTENSION, CONTEXTS.APP]
    fn: (ext) ->
      chrome.management.setEnabled ext.id, false
  options:
    desc: 'Open the options page of an extension or app'
    context: [CONTEXTS.EXTENSION, CONTEXTS.APP]
    fn: (ext) ->
      tab_open ext.optionsUrl
  describe:
    desc: 'Show description of extension or app'
    context: [CONTEXTS.EXTENSION, CONTEXTS.APP]
    fn: (ext) ->
      alert ext.description + ' -- Version: ' + ext.version
  homepage:
    desc: 'Open homepage of extension or app'
    context: [CONTEXTS.EXTENSION, CONTEXTS.APP]
    fn: (ext) ->
      tab_open ext.homepageUrl
  launch:
    desc: 'Launch app'
    context: CONTEXTS.APP
    fn: (app) ->
      chrome.management.launchApp app.id
  uninstall:
    desc: 'Uninstall extension or app'
    context: [CONTEXTS.EXTENSION, CONTEXTS.APP]
    fn: (ext) ->
      chrome.management.uninstall ext.id, {showConfirmDialog: true}
  add:
    desc: 'Add current tab to session'
    context: CONTEXTS.SESSION
    fn: (session) ->
      chrome.tabs.getCurrent (tab) =>
        s = sessions.get_by_name session.name
        wins = s.get 'wins'
        wins[0].url.push tab.url
        wins[0].pins.push tab.pinned
        s.save {wins}
  save:
    desc: 'Save the current window with the name given'
    context: CONTEXTS.TEXT
    fn: (name) ->
      chrome.windows.getCurrent (win) =>
        save_session name, [prepare win]
  save_all:
    desc: 'Save all open windows with the name given'
    context: CONTEXTS.TEXT
    fn: (name) ->
      chrome.windows.getAll {populate: true}, (wins) =>
        save_session name, prepare win for win in wins
  open:
    desc: 'Open saved session, bookmark, or special page'
    context: [CONTEXTS.SESSION, CONTEXTS.SPECIAL, CONTEXTS.BOOKMARK]
    fn: (page) ->
      if page.wins
        # it's actually a session. typechecking classes would be nice...
        open_session page
      else if page.url
        tab_open page.url
      else
        folder = page
        chrome.bookmarks.getChildren folder.id, (pages) ->
          if pages.length > 20
            return unless confirm "Open all #{pages.length} tabs in bookmark folder?"
          tab_open page.url for page in pages 
  delete:
    desc: 'Delete session or bookmark'
    context: [CONTEXTS.SESSION, CONTEXTS.BOOKMARKS]
    fn: (bookmark) ->
      if bookmark.wins # actually a session
        sessions.get_by_name(bookmark.name).destroy()
      else if bookmark.children and bookmark.children.length isnt 0
        chrome.bookmarks.removeTree bookmark.id if confirm "Recursively delete all #{bookmark.children.length} bookmarks in folder?"
      else
        chrome.bookmarks.remove bookmark.id

DEFAULTS =  # tied to CONTEXTS
  0: COMMANDS.select
  1: COMMANDS.options
  2: COMMANDS.launch
  3: COMMANDS.restore
  4: COMMANDS.history
  5: COMMANDS.open
  6: COMMANDS.open
  7: null
  8: null

  
COMMAND_NAMES = []

for name, cmd of COMMANDS
  context = cmd.context
  context = [context] unless context instanceof Array
  for c in context
    COMMAND_NAMES[c] or= []
    COMMAND_NAMES[c].push {name: sentence_case(name), cmd: cmd} 

prepare = (win) ->
  _.extend _.copy(win, 'left', 'top', 'width', 'height', 'focused'),
    urls: _(win.tabs).pluck 'url'
    pins: _(win.tabs).pluck 'pinned' #or just save a count?
    icons: _(win.tabs).pluck 'favIconUrl'

    
apply_to_matching_tabs = (text, fn) ->
  if text.url #is a tab
    tab = text
    if _(tab.url).startsWith 'chrome' or _(tab.url).startsWith 'about'
      apply_to_regex_tabs /^(chrome|about)/, fn
    else
      http = '^https*://'
      domain = tab.url.match(new RegExp(http + '(.*\..{2,4}/)', 'i'))[1]
      apply_to_regex_tabs(new RegExp(http + domain, 'i'), fn) if domain
  else
    apply_to_regex_tabs new RegExp(text, 'i'), fn

apply_to_regex_tabs = (regex, fn) ->
  tabs = get_tabs regex
  chrome.windows.getAll {populate: true}, (wins) =>
    tabs = tab for tab in _.flatten(win.tabs for win in wins) when regex.test tab.url
    fn tabs
  
# todo works? assumes order of pins is same as window, which api doesn't guarantee
open_session = (session) ->
  for win in session.wins
    win.url = win.urls.toString() #todo syntax http://developer.chrome.com/extensions/windows.html
    chrome.windows.create win, (new_win) => 
      for i in [0...win.tabs.length]
        chrome.tabs.update new_win.tabs[i].id, {pinned: win.pins[i]}

save_session = (name, wins) ->
  s = new Session {name, wins}
  sessions.add s
  s.save()
  
reload_window = (win) ->
  chrome.tabs.update(tab.id, url: tab.url) for tab in win.tabs

kill = (id) ->
  chrome.tabs.update id, url: 'about:kill'