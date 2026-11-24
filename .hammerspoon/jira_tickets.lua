-- Syncs the Jira issues assigned to me to Reminders with ~/.bin/jira-reminders, installed in
-- ~/bin with `mise run install`. It reads its credentials from the `jira` keyring service.
return require('reminders_sync').new({ name = 'jiraTickets', command = 'jira-reminders' })
