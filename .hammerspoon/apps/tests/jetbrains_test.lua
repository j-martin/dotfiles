rawset(_G, 'hs', rawget(_G, 'hs') or { logger = { new = function() end } })
package.loaded['apps/utils'] = package.loaded['apps/utils'] or {}
package.loaded['utils/process'] = package.loaded['utils/process'] or {}
local jetbrains = require 'apps/jetbrains'

---@type table<string, string>
local modes = {
  ['/src/code'] = 'directory',
  ['/src/code/infra'] = 'directory',
  ['/src/code/infra/Project.ts'] = 'file',
}

---@param path string
---@return string|nil
local function mode(path)
  return modes[path]
end

return {
  ['matches any IntelliJ based IDE'] = function()
    assert(jetbrains.matches('com.jetbrains.goland'))
    assert(jetbrains.matches('com.jetbrains.intellij.ce'))
    assert(jetbrains.matches('com.jetbrains.pycharm'))
    assert(jetbrains.matches('com.google.android.studio'))
  end,
  ['does not match other apps'] = function()
    assert(not jetbrains.matches('com.microsoft.VSCode'))
    assert(not jetbrains.matches('org.gnu.Emacs'))
    assert(not jetbrains.matches(nil))
  end,
  ['navigationPath joins the components up to the file'] = function()
    local components = { 'code', 'infra', 'Project.ts', 'Project', 'constructor(), method' }
    local path = jetbrains.navigationPath('/src/code', components, 'Project.ts', mode)
    assert(path == '/src/code/infra/Project.ts', path)
  end,
  ['navigationPath finds the file in the last folder when the bar shows a symbol instead'] = function()
    local path = jetbrains.navigationPath('/src/code', { 'code', 'infra', 'number, field' }, 'Project.ts', mode)
    assert(path == '/src/code/infra/Project.ts', path)
  end,
  ['navigationPath is nil without the project folder or the file'] = function()
    assert(jetbrains.navigationPath('/src/code', { 'other', 'infra' }, 'Project.ts', mode) == nil)
    assert(jetbrains.navigationPath('/src/code', { 'code', 'infra' }, 'a.go', mode) == nil)
    assert(jetbrains.navigationPath('/src/code', {}, 'Project.ts', mode) == nil)
  end,
}
