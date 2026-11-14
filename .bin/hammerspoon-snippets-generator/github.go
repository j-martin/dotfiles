// GitHub organization members, named from their SAML/SSO identity, whose NameID is the work email,
// e.g. jane.doe@example.com -> Jane Doe, since the SAML attributes hold no name. The GitHub profile name,
// then the login, are the fallbacks. The members and the SAML identities are fetched concurrently.
package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"regexp"
	"strings"
	"sync"
)

const (
	loginsGroupName = "GitHub - Coworkers"
	loginsFile      = "coworkers-github.json"
	emailsGroupName = "Email"
	emailsFile      = "coworkers-email.json"
)

type member struct {
	Login string `json:"login"`
	Name  string `json:"name"`
}

type samlIdentity struct {
	Login string `json:"login"`
	Email string `json:"email"`
}

const membersQuery = `
query($org: String!, $endCursor: String) {
  organization(login: $org) {
    membersWithRole(first: 100, after: $endCursor) {
      pageInfo { hasNextPage endCursor }
      nodes { login name }
    }
  }
}`

const samlQuery = `
query($org: String!, $endCursor: String) {
  organization(login: $org) {
    samlIdentityProvider {
      externalIdentities(first: 100, after: $endCursor) {
        pageInfo { hasNextPage endCursor }
        nodes { user { login } samlIdentity { nameId } }
      }
    }
  }
}`

// emailName matches the local part of first.last emails, e.g. jean-martin.archer.
var emailName = regexp.MustCompile(`^[a-z]+(-[a-z]+)*(\.[a-z]+(-[a-z]+)*)+$`)

// graphql runs a paginated query and decodes each JSON line printed by jq into a T.
func graphql[T any](query, org, jq string) ([]T, error) {
	out, err := run("gh", "api", "graphql", "--paginate", "-f", "query="+query, "-f", "org="+org, "--jq", jq)
	if err != nil {
		return nil, err
	}
	var items []T
	decoder := json.NewDecoder(bytes.NewReader(out))
	for decoder.More() {
		var item T
		if err := decoder.Decode(&item); err != nil {
			return nil, fmt.Errorf("decoding gh output: %w", err)
		}
		items = append(items, item)
	}
	return items, nil
}

// fetchGitHub returns the members of org and their SAML identities, fetched concurrently.
func fetchGitHub(org string) ([]member, []samlIdentity, error) {
	var members []member
	var identities []samlIdentity
	var membersErr, identitiesErr error
	var wg sync.WaitGroup
	wg.Go(func() {
		members, membersErr = graphql[member](membersQuery, org, ".data.organization.membersWithRole.nodes[]")
	})
	wg.Go(func() {
		identities, identitiesErr = graphql[samlIdentity](samlQuery, org,
			".data.organization.samlIdentityProvider.externalIdentities.nodes[]?"+
				" | select(.user != null) | {login: .user.login, email: (.samlIdentity.nameId // \"\")}")
	})
	wg.Wait()
	if membersErr != nil {
		return nil, nil, membersErr
	}
	if identitiesErr != nil {
		return nil, nil, identitiesErr
	}
	return members, identities, nil
}

// nameFromEmail returns the name of a first.last email, e.g. jean-martin.archer@example.com -> Jean-Martin Archer,
// or "" for other emails.
func nameFromEmail(email string) string {
	local, _, found := strings.Cut(strings.ToLower(email), "@")
	if !found || !emailName.MatchString(local) {
		return ""
	}
	words := strings.Split(local, ".")
	for i, word := range words {
		parts := strings.Split(word, "-")
		for j, part := range parts {
			parts[j] = strings.ToUpper(part[:1]) + part[1:]
		}
		words[i] = strings.Join(parts, "-")
	}
	return strings.Join(words, " ")
}

// coworker is a member with the name shown in the picker.
type coworker struct {
	Login string
	Email string
	Name  string
}

// coworkers returns the members named from their SAML email, otherwise their profile name, otherwise their login.
func coworkers(members []member, identities []samlIdentity) []coworker {
	emails := make(map[string]string, len(identities))
	for _, identity := range identities {
		emails[identity.Login] = identity.Email
	}
	result := make([]coworker, 0, len(members))
	for _, m := range members {
		email := emails[m.Login]
		name := nameFromEmail(email)
		if name == "" {
			name = strings.TrimSpace(m.Name)
		}
		if name == "" {
			name = m.Login
		}
		result = append(result, coworker{Login: m.Login, Email: email, Name: name})
	}
	return result
}

// coworkerGroup returns a group named name with a snippet per coworker whose text is not empty.
func coworkerGroup(name string, all []coworker, text func(coworker) string) snippetGroup {
	snippets := make([]snippet, 0, len(all))
	for _, c := range all {
		if t := text(c); t != "" {
			snippets = append(snippets, snippet{Desc: c.Name, Text: t})
		}
	}
	return newGroup(name, snippets)
}

// generateGitHub writes the coworker groups of org to dir.
func generateGitHub(dir, org string) error {
	members, identities, err := fetchGitHub(org)
	if err != nil {
		return err
	}
	if len(members) == 0 {
		return fmt.Errorf("no members found in %s", org)
	}
	all := coworkers(members, identities)
	if err := write(dir, loginsFile, coworkerGroup(loginsGroupName, all, func(c coworker) string { return c.Login })); err != nil {
		return err
	}
	return write(dir, emailsFile, coworkerGroup(emailsGroupName, all, func(c coworker) string { return c.Email }))
}
