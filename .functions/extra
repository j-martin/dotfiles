#!/usr/bin/env bash

_docker_pick_container () {
  local tag_prefix="$1"
  docker ps | _fzf "${tag_prefix}" | _pick_first_col
}

_docker_pick_images () {
  docker images | awk '{print $1 ":" $2}' | _fzf $1
}

_consul_list_services_dns () {
  local domain="$1"
  local node="${2:-consul}"
  curl --fail --silent "http://$node.service.$domain:8500/v1/catalog/services" \
    | jq -r 'to_entries[] | .key, ({key, value: .value[]} | .value + "." + .key)' \
    | sed "s/$/\.service\.$domain/"
}

_rds_pick_instance () {
  aws rds describe-db-instances | jq -r '.DBInstances[].DBInstanceIdentifier' | fzf
}

rds_logs (){
  local db_identifier="${1:-_rds_pick_instance}"
  aws rds describe-db-log-files --db-instance-identifier "$db_identifier" \
    | jq -r '.DescribeDBLogFiles[].LogFileName' \
    | xargs -n1 -P0 -r aws rds download-db-log-file-portion --db-instance-identifier "$db_identifier"  --log-file-name \
    | jq -r '.LogFileData' \
    | grep -v 'LOG:  checkpoint' \
    | sort \
    | less -SRi
}
