local logger = hs.logger.new('chromium', 'info')
local jxa = require 'utils/jxa'
local markdown = require 'utils/markdown'

--- Shared helpers for Chromium based browsers, e.g. Brave and Google Chrome.
---@class ChromiumModule
---@field context fun(appName: string): table<string, string>|nil
---@field openActiveTab fun(appName: string, open: fun(url: string))
---@field copyActiveTabAsMarkdownLink fun(appName: string)
local mod = {}

--- Returns the title and URL of the active tab of `appName`.
---@param appName string
---@return table<string, string>|nil
function mod.context(appName)
  local ok, tab = jxa.run("const t = Application('" .. appName .. "').windows[0].activeTab(); [t.title(), t.url()]")
  if not ok or type(tab) ~= 'table' then
    return nil
  end
  return { title = tab[1], url = tab[2] }
end

--- Calls `open` with the URL of the active tab of `appName`.
---@param appName string
---@param open fun(url: string)
function mod.openActiveTab(appName, open)
  local tab = mod.context(appName)
  if not tab then
    logger.ef('Could not get the URL of the active %s tab.', appName)
    return
  end
  open(tab.url)
end

--- Copies the active tab of `appName` to the clipboard as a Markdown link titled after the page title.
---@param appName string
function mod.copyActiveTabAsMarkdownLink(appName)
  local tab = mod.context(appName)
  if not tab then
    logger.ef('Could not get the active %s tab.', appName)
    return
  end
  local link = markdown.link(tab.title, tab.url)
  hs.pasteboard.setContents(link)
  hs.alert.show('Copied ' .. link)
end

return mod
