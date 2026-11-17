-- Message drafts in Obsidian, named after what the focused window shows, with a link to it when it has a URL.
local logger = hs.logger.new('obsidian', 'info')

---@class ObsidianApp
---@field name string
---@field fileName fun(time: number, title: string): string
---@field content fun(context: AppContext|nil): string
---@field newDraft fun()
local mod = {}

mod.name = 'Obsidian'

-- Characters Obsidian does not allow in file names, or that break links to them.
---@type string
local forbidden = '[\\/:%*"<>|%?#%^%[%]]'

---@type integer
local maxTitleLength = 100

--- Returns `<date>T<HH-MM-SS> - <title>.md` in local time, dashes replacing the colons Obsidian forbids.
---@param time number
---@param title string
---@return string
function mod.fileName(time, title)
  ---@type string
  local clean = title:gsub(forbidden, ' '):gsub('%s+', ' '):gsub('^[%s%.]+', ''):gsub('%s+$', '')
  if utf8.len(clean) and utf8.len(clean) > maxTitleLength then
    clean = clean:sub(1, utf8.offset(clean, maxTitleLength + 1) - 1):gsub('%s+$', '')
  end
  if clean == '' then
    clean = 'Draft'
  end
  return os.date('%Y-%m-%dT%H-%M-%S', time) .. ' - ' .. clean .. '.md'
end

--- Returns the initial note content, a markdown link to the context when it has a URL.
--- Newlines are escaped as the Obsidian CLI expects them.
---@param context AppContext|nil
---@return string
function mod.content(context)
  if not context or not context.url then
    return ''
  end
  ---@type string
  local title = context.title:gsub('%s+', ' '):gsub('([%[%]])', '\\%1')
  ---@type string
  local url = context.url:gsub('%s', '%%20'):gsub('%)', '%%29')
  return '[' .. title .. '](' .. url .. ')\\n\\n'
end

--- Creates and opens a draft in `config.obsidianDraftsFolder`, named after the focused window.
function mod.newDraft()
  local apps = require 'apps'
  local config = require 'config'
  local process = require 'utils/process'
  local context = apps.windowContext(hs.window.focusedWindow())
  local path = config.obsidianDraftsFolder .. '/' .. mod.fileName(os.time(), context and context.title or '')
  process.start(
    'obsidian',
    {
      'create',
      'vault=' .. config.obsidianDraftsVault,
      'path=' .. path,
      'content=' .. mod.content(context),
      'open',
    },
    nil,
    nil,
    {
      callback = function(exitCode, stdOut, stdErr)
        if exitCode ~= 0 or stdOut:match('^Error') then
          logger.ef('Failed to create %s: %s %s', path, stdOut, stdErr)
          hs.alert.show('Obsidian: ' .. (stdOut ~= '' and stdOut or 'failed to create the draft, see console'), 5)
          return
        end
        hs.application.launchOrFocus(mod.name)
      end,
    }
  )
end

return mod
