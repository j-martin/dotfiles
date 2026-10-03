-- Full screen overlay listing keybindings.
local mod = {}

local view
local closer

-- Sections registered by the binding modules, in registration order.
local registry = {}

local modifierSymbols = {cmd = '⌘', alt = '⌥', ctrl = '⌃', shift = '⇧'}

-- Render a modifier list, e.g. {'cmd', 'alt', 'ctrl'} -> '⌘⌥⌃'.
function mod.modifiersString(modifiers)
  local parts = {}
  for _, modifier in ipairs(modifiers or {}) do
    table.insert(parts, modifierSymbols[modifier] or modifier)
  end
  return table.concat(parts)
end

-- Register (or replace, when the title already exists) a section of bindings.
function mod.register(title, bindings)
  for _, section in ipairs(registry) do
    if section.title == title then
      section.bindings = bindings
      return
    end
  end
  table.insert(registry, {title = title, bindings = bindings})
end

function mod.close()
  if view then
    view:delete()
    view = nil
  end
  if closer then
    closer:exit()
  end
end

local function escapeHtml(s)
  return (s:gsub('&', '&amp;'):gsub('<', '&lt;'):gsub('>', '&gt;'))
end

-- Map functions to 'module.name' by scanning loaded modules.
local function functionNames()
  local names = {}
  for modName, module in pairs(package.loaded) do
    if type(module) == 'table' and modName ~= '_G' then
      pcall(function()
        for key, value in pairs(module) do
          if type(value) == 'function' and type(key) == 'string' and names[value] == nil then
            names[value] = modName .. '.' .. key
          end
        end
      end)
    end
  end
  return names
end

local function renderSection(section, fnNames)
  local rows = {}
  for _, binding in ipairs(section.bindings) do
    local key = binding.key == 'space' and '␣' or binding.key:upper()
    if binding.shift then
      key = '⇧' .. key
    end
    if binding.modifiers then
      key = mod.modifiersString(binding.modifiers) .. key
    end
    table.insert(rows, string.format(
      '<div class="row"><span class="key">%s</span><span class="desc">%s</span></div>',
      escapeHtml(key), escapeHtml(binding.desc or binding.name or fnNames[binding.fn] or '?')))
  end
  return string.format('<h2>%s</h2>%s', escapeHtml(section.title), table.concat(rows))
end

local style = [[
  html, body { margin: 0; height: 100%; overflow: hidden; }
  body { background: rgba(20, 20, 24, 0.92); color: #ddd;
         font: 14px -apple-system, sans-serif; padding: 24px 32px; box-sizing: border-box; }
  h2 { color: #fff; font-size: 16px; margin: 0 0 8px; border-bottom: 1px solid #444; padding-bottom: 4px;
       break-after: avoid; }
  h2:not(:first-child) { margin-top: 16px; }
  .cols { height: 100%; column-width: 260px; column-fill: auto; column-gap: 32px; }
  .row { display: flex; break-inside: avoid; padding: 2px 0; }
  .key { flex: 0 0 64px; font-family: Menlo, monospace; color: #f5c451; font-weight: bold; }
  .desc { flex: 1; }
  .hint { position: absolute; bottom: 12px; right: 32px; color: #777; font-size: 12px; }
]]

-- sections: { { title = 'string', bindings = { binding, ... } }, ... }
-- Defaults to all registered sections.
function mod.show(sections)
  mod.close()
  sections = sections or registry
  local fnNames = functionNames()

  local rendered = {}
  for _, section in ipairs(sections) do
    table.insert(rendered, renderSection(section, fnNames))
  end

  local html = '<html><head><style>' .. style .. '</style></head><body><div class="cols">'
    .. table.concat(rendered)
    .. '</div><div class="hint">Esc / q to close</div></body></html>'

  view = hs.webview.new(hs.screen.mainScreen():fullFrame())
    :windowStyle({'borderless'})
    :level(hs.drawing.windowLevels.modalPanel)
    :transparent(true)
    :allowTextEntry(false)
    :html(html)
    :show()
  view:bringToFront(true)

  if not closer then
    closer = hs.hotkey.modal.new()
    closer:bind({}, 'escape', mod.close)
    closer:bind({}, 'q', mod.close)
  end
  closer:enter()
end

return mod
