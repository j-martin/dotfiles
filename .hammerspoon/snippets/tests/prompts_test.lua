local prompts = require 'snippets/prompts'

---@param rows SnippetChoice[]
---@return string
local function values(rows)
  ---@type string[]
  local result = {}
  for _, row in ipairs(rows) do
    table.insert(result, row.value)
  end
  return table.concat(result, ',')
end

return {
  ['choicesOf normalizes strings and tables, the value defaulting to the text'] = function()
    local choices =
      assert(prompts.choicesOf({ name = 'env', choices = { 'dev', { text = 'Production', value = 'prod' } } }, {}))
    assert(values(choices) == 'dev,prod', values(choices))
    assert(choices[2].text == 'Production', 'expected the text to be kept')
  end,

  ['choicesOf gives the previous answers to a choices function'] = function()
    local prompt = {
      name = 'zone',
      choices = function(answers)
        return { answers.region .. '-a' }
      end,
    }
    local choices = assert(prompts.choicesOf(prompt, { region = 'us-east1' }))
    assert(values(choices) == 'us-east1-a', values(choices))
  end,

  ['choicesOf returns an error when the choices function fails'] = function()
    local choices, err = prompts.choicesOf({
      name = 'zone',
      choices = function()
        error('boom')
      end,
    }, {})
    assert(choices == nil and err and err:find('boom', 1, true), tostring(err))
  end,

  ['rows offers the typed text after the matching choices'] = function()
    local choices = assert(prompts.choicesOf({ name = 'env', choices = { 'dev', 'prod', 'preprod' } }, {}))
    local rows = prompts.rows({ name = 'env' }, choices, 'pro')
    assert(values(rows) == 'prod,preprod,pro', values(rows))
  end,

  ['rows does not offer the typed text when a choice is exactly it'] = function()
    local choices = assert(prompts.choicesOf({ name = 'env', choices = { 'dev', 'prod' } }, {}))
    assert(values(prompts.rows({ name = 'env' }, choices, 'prod')) == 'prod')
  end,

  ['rows of a strict prompt only offers choices'] = function()
    local prompt = { name = 'env', strict = true, choices = { 'dev', 'prod' } }
    local choices = assert(prompts.choicesOf(prompt, {}))
    assert(#prompts.rows(prompt, choices, 'qa') == 0, 'expected no rows')
  end,

  ['rows of a prompt without choices offers the typed text, even empty'] = function()
    assert(values(prompts.rows({ name = 'number' }, {}, '')) == '')
    assert(#prompts.rows({ name = 'number' }, {}, '') == 1, 'expected the empty typed text')
    assert(values(prompts.rows({ name = 'number' }, {}, '42')) == '42')
  end,

  ['fill replaces the placeholders of a text string with the answers'] = function()
    local snippet = { text = 'gh/{{ repo }}/pull/{{number}}', prompts = { { name = 'repo' }, { name = 'number' } } }
    local text = prompts.fill(snippet, { repo = 'a/b', number = '42%' })
    assert(text == 'gh/a/b/pull/42%', tostring(text))
  end,

  ['fill keeps the placeholders of no prompt'] = function()
    local snippet = { text = '{{ .Values.x }} {{ name }} {{ other }}', prompts = { { name = 'name' } } }
    local text = prompts.fill(snippet, { name = 'jm' })
    assert(text == '{{ .Values.x }} jm {{ other }}', tostring(text))
  end,

  ['fill keeps the placeholders of a snippet without prompts'] = function()
    assert(prompts.fill({ text = '{{ name }}' }, { name = 'jm' }) == '{{ name }}')
  end,

  ['fill calls the text function with the answers'] = function()
    local snippet = {
      text = function(answers)
        return 'PR #' .. answers.number
      end,
    }
    assert(prompts.fill(snippet, { number = '42' }) == 'PR #42')
  end,

  ['fill returns an error when the text function does not return a string'] = function()
    local text, err = prompts.fill({
      desc = 'Broken',
      text = function()
        ---@diagnostic disable-next-line: return-type-mismatch
        return 42
      end,
    }, {})
    assert(text == nil and err and err:find('Broken', 1, true), tostring(err))
  end,
}
