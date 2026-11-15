-- Emoji snippets, also written to the MacParakeet vocabulary: `desc` is the spoken word, `text` the replacement.
-- Like Slack, emoticons such as ':)' expand as typed, other emojis use their name, e.g. ':rofl:'.
-- `aliases` are extra triggers, e.g. ':ss:', they are not added to the vocabulary.

---@type SnippetGroup
local emojis = {
  prefix = '',
  suffix = '',
  snippets = {
    { trigger = ':)', text = '🙂', desc = 'smiling emoji' },
    { trigger = ';)', text = '😉', desc = 'wink emoji' },
    { trigger = ':sweat_smile:', aliases = { ':ss:' }, text = '😅', desc = 'sweat smile emoji' },
    { trigger = ':robot:', text = '🤖', desc = 'robot emoji' },
    { trigger = ':shrug:', text = '🤷', desc = 'shrug emoji' },
    { trigger = ':joy:', aliases = { 'X)' }, text = '😂', desc = 'laughing emoji' },
    { trigger = '(:', text = '🙃', desc = 'upside down emoji' },
    { trigger = ':100:', text = '💯', desc = 'hundred emoji' },
    { trigger = ':roll_eyes:', text = '🙄', desc = 'eye roll emoji' },
    { trigger = ":'(", text = '😭', desc = 'crying emoji' },
    { trigger = ':anxious:', text = '😰', desc = 'anxious emoji' },
    { trigger = ':speak_no_evil:', text = '🙊', desc = 'speak no evil emoji' },
    { trigger = '<3', text = '❤️', desc = 'heart emoji' },
    { trigger = ':wave:', aliases = { ':wa:' }, text = '👋', desc = 'wave emoji' },
    { trigger = ':facepalm:', text = '🤦', desc = 'facepalm emoji' },
    { trigger = ':see_no_evil:', text = '🙈', desc = 'see no evil emoji' },
    { trigger = ':hear_no_evil:', text = '🙉', desc = 'hear no evil emoji' },
    { trigger = ':drum:', text = '🥁', desc = 'drum emoji' },
    { trigger = ':rofl:', text = '🤣', desc = 'rofl emoji' },
    { trigger = ":')", text = '🥲', desc = 'smiling tear emoji' },
    { trigger = ':p', aliases = { ':P' }, text = '😛', desc = 'tongue out emoji' },
    { trigger = ':/', text = '😕', desc = 'confused emoji' },
    { trigger = 'shrug', desc = 'Shrug', text = '¯\\_(ツ)_/¯', skipVocabulary = true },
    { trigger = 'tflip', desc = 'Table flip', text = '(╯°□°)╯︵ ┻━┻', skipVocabulary = true },
  },
}

return emojis
