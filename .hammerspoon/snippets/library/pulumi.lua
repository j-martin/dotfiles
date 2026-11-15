-- Imported from the Alfred 'Pulumi' snippets folder, with its keyword prefix and suffix.
---@type SnippetGroup
return {
  name = 'Pulumi',
  prefix = '',
  suffix = '',
  snippets = {
    {
      desc = 'Pulumi - Parent with Alias',
      text = [=[
      {
        parent: this,
        aliases: [
          {
            parent: pulumi.rootStackResource,
          }
        ]
      }]=],
    },
    {
      desc = 'Pulumi - Standard Deps',
      text = [=[
      {
        parent: this,
        dependsOn: [cluster],
      }
]=],
    },
  },
}
