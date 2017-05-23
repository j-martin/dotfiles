#!/usr/bin/env python3

import keyring
import todoist
from collections import defaultdict
from os import path
import argparse

def main():
    parser = argparse.ArgumentParser(description='Format todos from todoist.')
    parser.add_argument('--output', help='Specify the was region.', default='~/.org/todoist.org')
    args = parser.parse_args()

    api_key = keyring.get_keyring().get_password('system', 'todoist')
    api = todoist.TodoistAPI(api_key)
    print(api_key)
    api.sync()

    projects = {p['id']: p['name'] for p in api.projects.all()}
    tasks = defaultdict(list)

    for item in api.items.all():
        tasks[projects[item['project_id']]].append(item)

    with open(path.expanduser(args.output), 'w') as fp:
        fp.write("#+TITLE: Todoist\n#+SETUPFILE: common.org\n")
        for project_name in tasks:
            fp.write(f"* {project_name}\n")
            for task in tasks[project_name]:
                state = 'TODO'
                if task['checked']:
                    state = 'DONE'
                entry = f"""** {state} {task['content']}
:PROPERTIES:
:URL: [[https://todoist.com/showTask?id={task['id']}&sync_id={task['id']}][url]]
:ID: {task['id']}
:ADDED: {task['date_added']}
:END:
"""
                fp.write(entry)

if __name__ == '__main__':
    main()
