-- Imported from the Alfred 'psql' snippets folder, with its keyword prefix and suffix.
---@type SnippetGroup
return {
  name = 'PSQL',
  aliases = { 'postgres', 'sql' },
  prefix = '',
  suffix = '  ',
  snippets = {
    {
      desc = 'get table size',
      text = "SELECT pg_size_pretty( pg_total_relation_size('tablename'));",
    },
    {
      desc = 'Postgres Reload Config',
      text = 'SELECT pg_reload_conf();',
    },
    {
      desc = 'PSQL Active Process',
      text = "select * from pg_stat_activity where state != 'idle';",
    },
    {
      desc = 'PSQL List locks',
      text = [=[
select relation::regclass, locktype, mode, granted FROM
pg_locks where relation::regclass::text != 'pg_locks';]=],
    },
    {
      desc = 'PSQL List Owner',
      text = [=[
select t.table_name, t.table_type, c.relname, c.relowner, u.usename
from information_schema.tables t
join pg_catalog.pg_class c on (t.table_name = c.relname)
join pg_catalog.pg_user u on (c.relowner = u.usesysid)
where t.table_schema='public';]=],
    },
    {
      desc = 'Replication Lag',
      text = 'select now()-pg_last_xact_replay_timestamp() as replication_lag;',
    },
    {
      trigger = 'sfrom',
      desc = 'Select From',
      text = 'SELECT * FROM ',
    },
    {
      trigger = 'srand',
      desc = 'Select random',
      text = 'SELECT * FROM {cursor} ORDER BY RANDOM() LIMIT 50;',
    },
    {
      trigger = 'scount',
      desc = 'SQL Count',
      text = 'SELECT count(*) FROM ',
    },
    {
      desc = 'MySQL - Disable Foreign Key Check',
      text = 'SET FOREIGN_KEY_CHECKS=0;',
    },
    {
      desc = 'MySQL - Process List',
      text = 'SHOW FULL PROCESSLIST;',
    },
  },
}
