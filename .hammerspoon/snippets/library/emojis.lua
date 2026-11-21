-- Emoji snippets, also written to the MacParakeet vocabulary: `desc` is the spoken word, `text` the replacement.
-- Like Slack, emoticons such as ':)' expand as typed, other emojis use their name, e.g. ':rofl:'.
-- `aliases` are extra triggers, e.g. ':ss:', they are not added to the vocabulary.

---@type SnippetGroup
local emojis = {
  name = 'Emoji',
  prefix = '',
  suffix = '',
  snippets = {
    { trigger = ":'(", text = '😭', desc = 'crying emoji' },
    { trigger = ":')", text = '🥲', desc = 'smiling tear emoji' },
    { trigger = '(:', text = '🙃', desc = 'upside down emoji' },
    { trigger = ':)', text = '🙂', desc = 'smiling emoji' },
    -- { trigger = ':/', text = '😕', desc = 'confused emoji' },
    { trigger = ':100:', text = '💯', desc = 'hundred emoji' },
    { trigger = ':anxious:', text = '😰', desc = 'anxious emoji' },
    { trigger = ':drum:', text = '🥁', desc = 'drum emoji' },
    { trigger = ':facepalm:', text = '🤦', desc = 'facepalm emoji' },
    { trigger = ':hear_no_evil:', text = '🙉', desc = 'hear no evil emoji' },
    { trigger = ':joy:', aliases = { 'X)' }, text = '😂', desc = 'laughing emoji' },
    { trigger = ':p', aliases = { ':P' }, text = '😛', desc = 'tongue out emoji' },
    { trigger = ':robot:', text = '🤖', desc = 'robot emoji' },
    { trigger = ':rofl:', text = '🤣', desc = 'rofl emoji' },
    { trigger = ':roll_eyes:', text = '🙄', desc = 'eye roll emoji' },
    { trigger = ':see_no_evil:', text = '🙈', desc = 'see no evil emoji' },
    { trigger = ':shrug:', text = '🤷', desc = 'shrug emoji' },
    { trigger = ':speak_no_evil:', text = '🙊', desc = 'speak no evil emoji' },
    { trigger = ':sweat_smile:', aliases = { ':ss:' }, text = '😅', desc = 'sweat smile emoji' },
    { trigger = ':tflip:', desc = 'Table flip', text = '(╯°□°)╯︵ ┻━┻', skipVocabulary = true },
    { trigger = ':wave:', aliases = { ':wa:' }, text = '👋', desc = 'wave emoji' },
    { trigger = ';)', text = '😉', desc = 'wink emoji' },
    { trigger = '<3', text = '❤️', desc = 'heart emoji' },
  },
}

return emojis
