-- Snippet expander: typed triggers expand in place, and a picker lists every snippet.
local logger = hs.logger.new('snippets', 'info')

local config = require 'config'
local emojis = require 'snippets/library/emojis'
local jsonSnippets = require 'snippets/json_snippets'
local matcher = require 'snippets/matcher'
local privateConfig = require 'utils/private_config'
local vocabulary = require 'snippets/vocabulary'

---@class SnippetsModule
---@field snippets Snippet[]
local mod = {
  snippets = {},
}

-- Kept at module level so they are not garbage collected.
---@type hs.eventtap|nil
local tap = nil
---@type hs.timer|nil
local watchdog = nil
---@type hs.chooser|nil
local chooser = nil
-- Enabled only while the picker is shown.
---@type hs.hotkey|nil
local copyHotkey = nil

---@type string
local buffer = ''
---@type integer
local maxLength = 0

-- Seconds between pasting a snippet and typing its trailing spaces, then moving the cursor back to its '{cursor}'.
---@type number
local pasteDelay = 0.1

local keyCodes = hs.keycodes.map
---@type table<integer, boolean>
local resetKeys = {
  [keyCodes['return']] = true,
  [keyCodes['padenter']] = true,
  [keyCodes['escape']] = true,
  [keyCodes['tab']] = true,
  [keyCodes['left']] = true,
  [keyCodes['right']] = true,
  [keyCodes['up']] = true,
  [keyCodes['down']] = true,
  [keyCodes['home']] = true,
  [keyCodes['end']] = true,
  [keyCodes['pageup']] = true,
  [keyCodes['pagedown']] = true,
}

--- Returns `text` with its placeholders replaced, how many characters the cursor moves back and its trailing spaces.
---@param text string
---@return string rendered
---@return integer cursorBack
---@return string trailing
local function render(text)
  return matcher.render(text, {
    date = os.date('%Y-%m-%d') --[[@as string]],
    time = os.date('%H:%M') --[[@as string]],
    clipboard = hs.pasteboard.getContents() or '',
  })
end

--- Pastes `text` into the focused app with its placeholders replaced, then restores the previous clipboard.
---@param text string
function mod.insert(text)
  local previous = hs.pasteboard.readAllData()
  local rendered, cursorBack, trailing = render(text)
  hs.pasteboard.setContents(rendered)
  hs.eventtap.keyStroke({ 'cmd' }, 'v', 0)
  -- Apps paste asynchronously, keys sent right away can land before the text.
  if cursorBack > 0 or trailing ~= '' then
    hs.timer.doAfter(pasteDelay, function()
      hs.eventtap.keyStrokes(trailing)
      for _ = 1, cursorBack do
        hs.eventtap.keyStroke({}, 'left', 0)
      end
    end)
  end
  hs.timer.doAfter(0.3, function()
    if previous and next(previous) then
      hs.pasteboard.writeAllData(previous)
    end
  end)
end

--- Plays `config.snippetSound`, if set, to confirm an expansion.
local function playSound()
  if not config.snippetSound then
    return
  end
  local sound = hs.sound.getByName(config.snippetSound)
  if sound then
    sound:play()
  else
    logger.w('Unknown snippet sound: ' .. config.snippetSound)
  end
end

--- Deletes the typed trigger and inserts the snippet text, without the tap seeing its own keystrokes.
---@param snippet Snippet
---@param trigger string The trigger or alias that was typed.
local function expand(snippet, trigger)
  hs.timer.doAfter(0, function()
    if tap then
      tap:stop()
    end
    for _ = 1, utf8.len(trigger) or #trigger do
      hs.eventtap.keyStroke({}, 'delete', 0)
    end
    mod.insert(snippet.text .. matcher.appendFor(snippet, trigger))
    if tap then
      tap:start()
    end
    playSound()
  end)
end

--- Returns whether the frontmost app uses vim bindings, see `config.vimApps`.
---@return boolean
local function usesVim()
  local app = hs.application.frontmostApplication()
  local bundleID = app and app:bundleID()
  return bundleID ~= nil and hs.fnutils.contains(config.vimApps, bundleID)
end

-- Returning false lets every event through; expansion happens after the key is typed.
-- Clicks reset the buffer since they usually move the cursor.
---@param event hs.eventtap.event
---@return boolean
local function onEvent(event)
  if event:getType() ~= hs.eventtap.event.types.keyDown or hs.eventtap.isSecureInputEnabled() then
    buffer = ''
    return false
  end
  local flags = event:getFlags()
  local keyCode = event:getKeyCode()
  if flags.cmd or flags.ctrl or flags.alt or flags.fn or resetKeys[keyCode] then
    buffer = ''
    return false
  end
  if keyCode == keyCodes['delete'] then
    buffer = matcher.pop(buffer)
    return false
  end
  local char = event:getCharacters()
  if char == nil or char == '' then
    return false
  end
  buffer = matcher.push(buffer, char, maxLength)
  local snippet, trigger = matcher.findMatch(buffer, mod.snippets, usesVim())
  if snippet and trigger then
    logger.df('Expanding %s', trigger)
    buffer = ''
    expand(snippet, trigger)
  end
  return false
end

--- Shows every snippet in a searchable list and pastes the one picked.
function mod.pick()
  local window = hs.window.focusedWindow()
  if chooser then
    chooser:delete()
  end
  chooser = hs.chooser.new(function(choice)
    if window then
      window:focus()
    end
    if choice then
      hs.timer.doAfter(0.2, function()
        mod.insert(choice.snippetText)
      end)
    end
  end)
  ---@param query string
  ---@return table[]
  local function choices(query)
    ---@type table[]
    local result = {}
    for _, snippet in ipairs(mod.snippets) do
      if matcher.matchesQuery(snippet, query) then
        table.insert(result, {
          text = matcher.label(snippet),
          subText = table.concat(snippet.shown or matcher.triggersOf(snippet), ' ')
            .. '  '
            .. snippet.text:gsub('%s+', ' '),
          snippetText = snippet.text,
        })
      end
    end
    return result
  end
  chooser:bgDark(true)
  chooser:placeholderText('Snippets')
  -- Every word of the query must match, so 'gh review' finds 'GitHub - Re-review' through its group alias.
  chooser:queryChangedCallback(function(query)
    if chooser then
      chooser:choices(choices(query))
    end
  end)
  chooser:choices(choices(''))
  -- Copies the highlighted snippet instead of inserting it.
  copyHotkey = copyHotkey
    or hs.hotkey.new({ 'cmd' }, 'c', function()
      local row = chooser and chooser:selectedRowContents()
      if not row or not row.snippetText then
        return
      end
      local text, _, trailing = render(row.snippetText)
      local copied = text .. trailing
      hs.pasteboard.setContents(copied)
      if chooser then
        chooser:hide()
      end
      ---@type string
      local preview = copied
      ---@type integer|nil
      local cut = utf8.offset(copied, 101)
      if cut and cut <= #copied then
        preview = copied:sub(1, cut - 1) .. '…'
      end
      hs.alert.show('Copied: ' .. preview)
    end)
  chooser:showCallback(function()
    if copyHotkey then
      copyHotkey:enable()
    end
  end)
  chooser:hideCallback(function()
    if copyHotkey then
      copyHotkey:disable()
    end
  end)
  chooser:show()
end

--- Writes the emojis to the MacParakeet vocabulary, only when its words changed.
function mod.writeVocabulary()
  local path = config.macParakeetVocabularyPath
  ---@type MacParakeetVocabulary|nil
  local existing = hs.fs.attributes(path) and hs.json.read(path) or nil
  ---@type string
  local now = os.date('!%Y-%m-%dT%H:%M:%SZ') --[[@as string]]
  local updated = vocabulary.build(existing, emojis.snippets, now)
  if not vocabulary.hasChanged(existing, updated) then
    return
  end
  local file = io.open(path, 'w')
  if not file then
    logger.ef('Failed to write the vocabulary to %s', path)
    return
  end
  file:write(vocabulary.encode(updated))
  file:close()
  logger.f('Wrote %d words to %s', #updated.customWords, path)
end

-- A file of snippets per category, e.g. `snippets/library/shell.lua`.
---@type string
local libraryPath = hs.configdir .. '/snippets/library'

--- Returns the keys of `tbl`, sorted.
---@param tbl table<string, any>
---@return string[]
local function sortedKeys(tbl)
  ---@type string[]
  local keys = {}
  for key in pairs(tbl) do
    table.insert(keys, key)
  end
  table.sort(keys)
  return keys
end

--- Returns the snippet groups of `libraryPath` by category, including file snippets in matching subdirectories.
---@return table<string, SnippetGroup>
local function loadLibrary()
  ---@type table<string, SnippetGroup>
  local library = {}
  if not hs.fs.attributes(libraryPath) then
    return library
  end
  for file in hs.fs.dir(libraryPath) do
    local category = file:match('^([^.].*)%.lua$')
    if category then
      local path = libraryPath .. '/' .. file
      local ok, group = pcall(dofile, path)
      if ok and type(group) == 'table' and type(group.snippets) == 'table' then
        local snippetsPath = libraryPath .. '/' .. category
        local attributes = hs.fs.attributes(snippetsPath)
        if attributes and attributes.mode == 'directory' then
          ---@type string[]
          local snippetFiles = {}
          for snippetFile in hs.fs.dir(snippetsPath) do
            local snippetAttributes = hs.fs.attributes(snippetsPath .. '/' .. snippetFile)
            if snippetAttributes and snippetAttributes.mode == 'file' and not snippetFile:match('^%.') then
              table.insert(snippetFiles, snippetFile)
            end
          end
          table.sort(snippetFiles)
          for _, snippetFile in ipairs(snippetFiles) do
            local snippetPath = snippetsPath .. '/' .. snippetFile
            local handle, openError = io.open(snippetPath, 'r')
            if not handle then
              logger.ef('Failed to read snippet %s: %s', snippetPath, openError)
            else
              local metadata, text = matcher.splitHeader(handle:read('a'))
              handle:close()
              if not metadata then
                logger.ef('Invalid snippet %s: expected a # {...} JSON header in the top comment block', snippetPath)
              else
                local decoded, snippet = pcall(hs.json.decode, metadata)
                if decoded and type(snippet) == 'table' then
                  snippet.text = text
                  table.insert(group.snippets, snippet)
                else
                  local errorMessage = decoded and 'expected a JSON object' or tostring(snippet)
                  logger.ef('Invalid snippet %s: %s', snippetPath, errorMessage)
                end
              end
            end
          end
        end
        library[category] = group
      else
        logger.ef('Invalid snippets %s: %s', path, group)
      end
    end
  end
  return library
end

--- Returns a group per `*.json` file in `config.snippetJsonPath`, see `snippets/json_snippets.lua`.
---@return SnippetGroup[]
local function loadJsonFiles()
  ---@type SnippetGroup[]
  local groups = {}
  local directory = config.snippetJsonPath
  if not hs.fs.attributes(directory) then
    return groups
  end
  ---@type string[]
  local files = {}
  for file in hs.fs.dir(directory) do
    if file:match('^[^.].*%.json$') then
      table.insert(files, file)
    end
  end
  table.sort(files)
  for _, file in ipairs(files) do
    local path = directory .. '/' .. file
    local ok, decoded = pcall(hs.json.read, path)
    if not ok or decoded == nil then
      logger.ef('Failed to read snippets %s: %s', path, decoded)
    else
      local group, errors = jsonSnippets.parse(decoded, path)
      for _, message in ipairs(errors) do
        logger.e('Invalid snippet ' .. message)
      end
      table.insert(groups, group)
    end
  end
  return groups
end

--- Loads the library snippets, then the JSON ones, then the private ones, each wrapped by its group prefix and suffix.
--- The private `snippets` are either a list using the default prefix and suffix, a `SnippetGroup` or a list of them.
function mod.load()
  local library = loadLibrary()
  ---@type SnippetGroup[]
  local groups = {}
  for _, category in ipairs(sortedKeys(library)) do
    table.insert(groups, library[category])
  end
  for _, group in ipairs(loadJsonFiles()) do
    table.insert(groups, group)
  end
  for _, group in ipairs(matcher.privateGroups(privateConfig.get('snippets'))) do
    table.insert(groups, group)
  end
  mod.snippets = matcher.flatten(groups, config.snippetPrefix, config.snippetSuffix)
  maxLength = matcher.bufferLength(mod.snippets)
  logger.f('Loaded %d snippets', #mod.snippets)
end

--- Loads the snippets and starts expanding typed triggers.
function mod.init()
  mod.load()
  mod.writeVocabulary()
  if tap then
    tap:stop()
  end
  if watchdog then
    watchdog:stop()
  end
  local types = hs.eventtap.event.types
  tap = hs.eventtap.new({ types.keyDown, types.leftMouseDown, types.rightMouseDown }, onEvent)
  tap:start()
  -- macOS disables event taps that are too slow to answer.
  watchdog = hs.timer.doEvery(5, function()
    if tap and not tap:isEnabled() then
      logger.w('Snippet expander was disabled, restarting it')
      tap:start()
    end
  end)
end

return mod
