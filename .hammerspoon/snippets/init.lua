-- Snippet expander: typed triggers expand in place, and a picker lists every snippet.
local logger = hs.logger.new('snippets', 'info')

local config = require 'config'
local confirm = require 'utils/confirm'
local emojis = require 'snippets/library/emojis'
local jsonSnippets = require 'snippets/json_snippets'
local matcher = require 'snippets/matcher'
local privateConfig = require 'utils/private_config'
local prompts = require 'snippets/prompts'
local selection = require 'selection'
local tsvSnippets = require 'snippets/tsv_snippets'
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
---@type hs.chooser|nil
local groupChooser = nil
-- Enabled only while the picker is shown.
---@type hs.hotkey|nil
local copyHotkey = nil
-- Snippets of the picker, its rows hold their index.
---@type Snippet[]
local shownSnippets = {}

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

--- Types `trailing`, spaces and tabs, as key presses like the cursor moves after it.
--- Typed as a string, some apps handle it after the cursor moves: '[](x#L3) ' -> '[](x#L 3)'.
---@param trailing string
local function typeTrailing(trailing)
  for character in trailing:gmatch('.') do
    hs.eventtap.keyStroke({}, character == '\t' and 'tab' or 'space', 0)
  end
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
      typeTrailing(trailing)
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

--- Calls `onText` with the text of `snippet`, after asking its prompts, if any, and focusing `window` again.
--- Nothing is called when a prompt is cancelled or the text function fails.
---@param snippet Snippet
---@param window hs.window|nil Focused again after the prompts.
---@param onText fun(text: string)
local function resolve(snippet, window, onText)
  ---@param values table<string, string>
  local function finish(values)
    local text, err = prompts.fill(snippet, values)
    if not text then
      logger.e(err)
      hs.alert.show('Snippets - ' .. err)
      return
    end
    onText(text)
  end
  if not snippet.prompts or #snippet.prompts == 0 then
    finish({})
    return
  end
  prompts.ask(snippet.prompts, function(values)
    if window then
      window:focus()
    end
    if values then
      hs.timer.doAfter(0.2, function()
        finish(values)
      end)
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
--- With prompts, the trigger is only deleted once they are answered, and kept when one is cancelled.
---@param snippet Snippet
---@param trigger string The trigger or alias that was typed.
local function expand(snippet, trigger)
  local window = hs.window.focusedWindow()
  hs.timer.doAfter(0, function()
    resolve(snippet, window, function(text)
      if tap then
        tap:stop()
      end
      for _ = 1, utf8.len(trigger) or #trigger do
        hs.eventtap.keyStroke({}, 'delete', 0)
      end
      mod.insert(text .. matcher.appendFor(snippet, trigger))
      if tap then
        tap:start()
      end
      playSound()
    end)
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

--- Shows `snippets` in a searchable list and pastes the one picked into `window`.
---@param snippets Snippet[]
---@param placeholder string
---@param window hs.window|nil Focused again before pasting.
---@param withoutGroup boolean|nil Leaves the group out of the labels, e.g. when every snippet is in the same group.
local function showSnippets(snippets, placeholder, window, withoutGroup)
  if chooser then
    chooser:delete()
  end
  shownSnippets = snippets
  chooser = hs.chooser.new(function(choice)
    if window then
      window:focus()
    end
    local snippet = choice and shownSnippets[choice.snippetIndex]
    if snippet then
      hs.timer.doAfter(0.2, function()
        resolve(snippet, window, mod.insert)
      end)
    end
  end)
  ---@param query string
  ---@return table[]
  local function choices(query)
    ---@type table[]
    local result = {}
    for index, snippet in ipairs(snippets) do
      if matcher.matchesQuery(snippet, query) then
        table.insert(result, {
          text = matcher.label(snippet, withoutGroup),
          subText = table.concat(snippet.shown or matcher.triggersOf(snippet), ' ') .. '  ' .. matcher
            .preview(snippet)
            :gsub('%s+', ' '),
          snippetIndex = index,
        })
      end
    end
    return result
  end
  chooser:bgDark(true)
  chooser:placeholderText(placeholder)
  -- Every word of the query must match, so 'gh review' finds 'GitHub - Re-review' through its group alias.
  chooser:queryChangedCallback(function(query)
    if chooser then
      chooser:choices(choices(query))
    end
  end)
  chooser:choices(choices(''))
  -- Copies the highlighted snippet instead of inserting it, after asking its prompts.
  copyHotkey = copyHotkey
    or hs.hotkey.new({ 'cmd' }, 'c', function()
      local row = chooser and chooser:selectedRowContents()
      local snippet = row and shownSnippets[row.snippetIndex]
      if not snippet then
        return
      end
      if chooser then
        chooser:hide()
      end
      -- Prompts are shown once the picker is closed.
      hs.timer.doAfter(0, function()
        resolve(snippet, nil, function(resolved)
          local text, _, trailing = render(resolved)
          local copied = text .. trailing
          hs.pasteboard.setContents(copied)
          ---@type string
          local preview = copied
          ---@type integer|nil
          local cut = utf8.offset(copied, 101)
          if cut and cut <= #copied then
            preview = copied:sub(1, cut - 1) .. '…'
          end
          hs.alert.show('Copied: ' .. preview)
        end)
      end)
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

--- Shows every snippet in a searchable list and pastes the one picked.
function mod.pick()
  showSnippets(mod.snippets, 'Snippets', hs.window.focusedWindow())
end

--- Shows the emoji snippets in a searchable list and pastes the one picked.
function mod.pickEmoji()
  local name = emojis.name or matcher.ungrouped
  showSnippets(matcher.inGroup(mod.snippets, name), name, hs.window.focusedWindow(), true)
end

--- Shows the snippet groups in a searchable list, then the snippets of the one picked, and pastes the snippet picked.
function mod.pickByGroup()
  local window = hs.window.focusedWindow()
  if groupChooser then
    groupChooser:delete()
  end
  groupChooser = hs.chooser.new(function(choice)
    if not choice then
      if window then
        window:focus()
      end
      return
    end
    -- Shown once the group picker is closed.
    hs.timer.doAfter(0, function()
      showSnippets(matcher.inGroup(mod.snippets, choice.groupName), choice.groupName, window, true)
    end)
  end)
  local groups = matcher.groups(mod.snippets)
  ---@param query string
  ---@return table[]
  local function choices(query)
    ---@type table[]
    local result = {}
    for _, group in ipairs(groups) do
      if matcher.groupMatchesQuery(group, query) then
        table.insert(result, {
          text = group.name,
          subText = string.format('%d snippets', group.count),
          groupName = group.name,
        })
      end
    end
    return result
  end
  groupChooser:bgDark(true)
  groupChooser:placeholderText('Snippet groups')
  groupChooser:queryChangedCallback(function(query)
    if groupChooser then
      groupChooser:choices(choices(query))
    end
  end)
  groupChooser:choices(choices(''))
  groupChooser:show()
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

---@class TsvSnippetFile
---@field file string File name, e.g. 'new.tsv'.
---@field snippets Snippet[]

--- Returns the names of the `*.tsv` files in `directory`, sorted, none when it does not exist.
---@param directory string
---@return string[]
local function listTsvFiles(directory)
  ---@type string[]
  local files = {}
  if not hs.fs.attributes(directory) then
    return files
  end
  for file in hs.fs.dir(directory) do
    if file:match('^[^.].*%.tsv$') then
      table.insert(files, file)
    end
  end
  table.sort(files)
  return files
end

--- Returns the valid snippets of every `*.tsv` file in `directory`, sorted by file name, logging the invalid ones.
---@param directory string
---@return TsvSnippetFile[]
local function readTsvFiles(directory)
  ---@type TsvSnippetFile[]
  local result = {}
  for _, file in ipairs(listTsvFiles(directory)) do
    local path = directory .. '/' .. file
    local handle, openError = io.open(path, 'r')
    if not handle then
      logger.ef('Failed to read snippets %s: %s', path, openError)
    else
      local list, errors = tsvSnippets.parse(handle:read('a'), path)
      handle:close()
      for _, message in ipairs(errors) do
        logger.e('Invalid snippet ' .. message)
      end
      table.insert(result, { file = file, snippets = list })
    end
  end
  return result
end

--- Returns the snippet groups of `libraryPath` by category, including file snippets in matching subdirectories and
--- `<category>.tsv` snippets, a TSV file without a matching `<category>.lua` being its own group.
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
  for _, tsv in ipairs(readTsvFiles(libraryPath)) do
    local category = tsv.file:gsub('%.tsv$', '')
    local group = library[category]
    if group then
      for _, snippet in ipairs(tsv.snippets) do
        table.insert(group.snippets, snippet)
      end
    else
      library[category] = { name = tsvSnippets.groupName(tsv.file), snippets = tsv.snippets }
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

--- Returns a group per `*.tsv` file in `config.snippetTsvPath`, named after the file, see `tsvSnippets.groupName`.
---@return SnippetGroup[]
local function loadTsvFiles()
  ---@type SnippetGroup[]
  local groups = {}
  for _, tsv in ipairs(readTsvFiles(config.snippetTsvPath)) do
    table.insert(groups, { name = tsvSnippets.groupName(tsv.file), snippets = tsv.snippets })
  end
  return groups
end

--- Appends `text` with `desc` and without trigger to the `file` of `config.snippetTsvPath`, then reloads the snippets.
---@param file string e.g. 'new.tsv'.
---@param text string
---@param desc string|nil
local function appendToTsvFile(file, text, desc)
  local directory = config.snippetTsvPath
  local path = directory .. '/' .. file
  if not hs.fs.attributes(directory) then
    local created, mkdirError = hs.fs.mkdir(directory)
    if not created then
      logger.ef('Failed to create %s: %s', directory, mkdirError)
      hs.alert.show('Snippets - Failed to create ' .. directory)
      return
    end
  end
  ---@type string
  local separator = ''
  local existing = io.open(path, 'r')
  if existing then
    local content = existing:read('a')
    existing:close()
    if content ~= '' and content:sub(-1) ~= '\n' then
      separator = '\n'
    end
  end
  local handle, openError = io.open(path, 'a')
  if not handle then
    logger.ef('Failed to write %s: %s', path, openError)
    hs.alert.show('Snippets - Failed to write ' .. path)
    return
  end
  handle:write(separator .. tsvSnippets.encode(text, nil, desc))
  handle:close()
  mod.load()
  hs.alert.show('Snippets - Added to ' .. file)
end

--- Asks to confirm, then appends the selected text, or the clipboard text when nothing is selected,
--- without trigger to a TSV file of `config.snippetTsvPath`, and reloads the snippets.
--- The text typed in the confirmation is the description, none when blank.
--- With more than one TSV file, asks which one, `config.snippetTsvNewFile` selected first.
function mod.addFromSelection()
  local text, source = selection.getSelectedTextOrClipboard()
  if not text:match('%S') then
    hs.alert.show('Snippets - Nothing selected and clipboard has no text')
    return
  end
  confirm.prompt(
    'Add the ' .. source .. ' as a snippet',
    text,
    'Description (optional), ⏎ to confirm, esc to cancel',
    function(input)
      ---@type string|nil
      local desc = input:match('^%s*(.-)%s*$')
      if desc == '' then
        desc = nil
      end
      local files = tsvSnippets.targetFiles(listTsvFiles(config.snippetTsvPath), config.snippetTsvNewFile)
      if #files == 1 then
        appendToTsvFile(files[1], text, desc)
        return
      end
      ---@type ConfirmOption[]
      local options = {}
      for _, file in ipairs(files) do
        table.insert(options, { text = tsvSnippets.groupName(file), subText = file })
      end
      -- Shown once the description prompt is closed.
      hs.timer.doAfter(0, function()
        confirm.choose('Save the snippet to', options, function(index)
          appendToTsvFile(files[index], text, desc)
        end)
      end)
    end
  )
end

--- Loads the library snippets, then the JSON ones, then the TSV ones, then the private config ones, each wrapped by its group prefix and suffix.
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
  for _, group in ipairs(loadTsvFiles()) do
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
