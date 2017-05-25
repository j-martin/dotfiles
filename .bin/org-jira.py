#!/usr/bin/env python3

import keyring
from jira import JIRA
import argparse


def main():
    parser = argparse.ArgumentParser(description='Format todos from jira.')
    parser.add_argument('--query', help='JQL query to run', default='status != Backlog AND resolution = null AND assignee = currentuser()')
    args = parser.parse_args()
    url = keyring.get_keyring().get_password('system', 'jira-url')
    username = keyring.get_keyring().get_password('system', 'jira-user')
    password = keyring.get_keyring().get_password('system', 'jira')
    jira = JIRA(url, basic_auth=(username, password))
    print(list_issues(jira, args.query))


def list_issues(jira, query):
    return "\n".join([format_issue(i) for i in
                      jira.search_issues(query, fields='summary,status,description,comment,created,updated')])


def format_issue(issue):
    status = issue.fields.status.name.upper()
    if status != 'DONE':
        status = 'TODO'

    return f"""** {status} [[{issue.permalink()}][{issue.key} {issue.fields.summary}]]
:PROPERTIES:
:URL: {issue.permalink()}
:ID: {issue.key}
:CREATED: {issue.fields.created}
:UPDATED: {issue.fields.updated}
:END:

{issue.fields.description}

{format_comments(issue)}
"""


def format_comments(issue):
    comments = issue.fields.comment.comments

    if len(comments) == 0:
        return ""

    results = ['*** Comments']
    for comment in comments:
        result = f"""
Author: {comment.author.displayName}
Created: {comment.created}
Updated: {comment.updated}
{comment.body}
"""
        results.append(result)

    return "\n".join(results)


if __name__ == '__main__':
    main()
