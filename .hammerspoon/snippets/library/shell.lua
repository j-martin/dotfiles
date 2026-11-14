-- Imported from the Alfred 'shell' snippets folder, with its keyword prefix and suffix.
---@type SnippetGroup
return {
  name = 'Shell',
  prefix = '',
  suffix = '  ',
  snippets = {
    {
      desc = 'Apt Upgrade only',
      text = 'apt update && apt-get install --only-upgrade',
    },
    {
      desc = 'cat file',
      text = [=[
cat <<EOF > {cursor}

EOF]=],
    },
    {
      desc = 'clean iptable sshguard',
      text = 'sudo iptables -F sshguard',
    },
    {
      desc = 'docker connect to host machine',
      text = 'host.docker.internal',
    },
    {
      desc = 'find 1 level',
      text = 'find . -mindepth 1 -maxdepth 1',
    },
    {
      desc = 'Get current java flags',
      text = 'java -XX:+PrintFlagsFinal -version',
    },
    {
      trigger = 'gclone',
      desc = 'Git Clone',
      text = "git clone {clipboard} && cd $(basename ' {clipboard}' | sed 's/.git$//')",
    },
    {
      trigger = 'k8s',
      desc = 'kubernetes',
      text = 'kubernetes',
    },
    {
      desc = 'List all crontabs',
      text = 'tail -n9999999 /var/spool/cron/crontabs/*',
    },
    {
      trigger = 'init',
      desc = 'List all init / services',
      text = '{ find /etc/init; find /etc/init.d; find /etc/systemd/system; } | grep ',
    },
    {
      trigger = 'la',
      desc = 'List all',
      text = 'ls -lha ',
    },
    {
      desc = 'List SSHguard active rules',
      text = 'iptables -nvL sshguard',
    },
    {
      trigger = '127',
      desc = 'Local host',
      text = '127.0.0.1',
    },
    {
      trigger = 'myip',
      desc = 'My IP',
      text = 'curl http://ip6.me/api/',
    },
    {
      trigger = 'ps',
      desc = 'ps',
      text = 'ps -ef | grep -i {cursor} | less -SRi',
    },
    {
      desc = 'Stderr and Stdout to dev/null',
      text = ' > /dev/null 2>&1',
    },
    {
      desc = 'Stderr to devnull',
      text = ' 2> /dev/null',
    },
    {
      desc = 'Stderr to Stdout',
      text = '2>&1',
    },
    {
      trigger = 'ssa',
      desc = 'Sudo Alloy',
      text = 'sudo su - alloy',
    },
    {
      trigger = 'ssj',
      desc = 'Sudo Jenkins',
      text = 'sudo su - jenkins',
    },
    {
      trigger = 'ss',
      desc = 'sudo su -',
      text = 'sudo su - ',
    },
    {
      trigger = 'tf',
      desc = 'Terraform',
      text = 'terraform  {cursor}',
    },
    {
      desc = 'View TLS/SSL cert',
      text = [=[curl -vk https://{cursor} | awk 'BEGIN { cert=0 } /^\* SSL connection/ { cert=1 } /^\*/ { if (cert) print }']=],
    },
  },
}
