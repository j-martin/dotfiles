-- Imported from the Alfred 'gcp' snippets folder, with its keyword prefix and suffix.
---@type SnippetGroup
return {
  name = 'GCP',
  prefix = '',
  suffix = '',
  snippets = {
    {
      desc = 'K8s FQDN DNS',
      text = '<namespace>.svc.cluster.local',
    },
    {
      desc = 'Get instance metadata',
      text = 'curl "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token" -H "Metadata-Flavor: Google"',
    },
  },
}
