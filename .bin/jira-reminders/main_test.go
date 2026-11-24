package main

import (
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"reflect"
	"testing"
)

const base = "https://x.atlassian.net"

func TestNoteURL(t *testing.T) {
	tests := map[string]string{
		"jira-reminders <https://x.atlassian.net/browse/AB-1>\n\n#jira": "https://x.atlassian.net/browse/AB-1",
		"jira-reminders <https://x.atlassian.net/browse/AB2_C-12>":      "https://x.atlassian.net/browse/AB2_C-12",
		"https://x.atlassian.net/browse/AB-1":                           "",
		"jira-reminders <https://x.atlassian.net/browse/ab-1>":          "",
		"jira-reminders <https://x.atlassian.net/projects/AB>":          "",
		"see jira-reminders <https://x.atlassian.net/browse/AB-1>":      "",
		"": "",
	}
	for body, want := range tests {
		if got := noteURL(body); got != want {
			t.Errorf("noteURL(%q) = %q, want %q", body, got, want)
		}
	}
}

func TestPlan(t *testing.T) {
	is := func(key string) issue {
		i := issue{Key: key}
		i.Fields.Summary = "Fix"
		i.Fields.Status.Name = "In Progress"
		return i
	}
	issues := []issue{is("AB-1"), is("AB-2"), is("AB-3"), is("AB-6")}
	reminders := []reminder{
		{ID: "open", Name: "🎫 AB-2 [In Progress]: Fix", Body: "jira-reminders <https://x.atlassian.net/browse/AB-2>\n\n#jira"},
		{ID: "done", Name: "🎫 AB-3 [In Progress]: Fix", Body: "jira-reminders <https://x.atlassian.net/browse/AB-3>", Completed: true},
		{ID: "moved", Name: "🎫 AB-6 [To Do]: Fix", Body: "jira-reminders <https://x.atlassian.net/browse/AB-6>"},
		{ID: "stale", Body: "jira-reminders <https://x.atlassian.net/browse/AB-4>"},
		{ID: "stale-done", Body: "jira-reminders <https://x.atlassian.net/browse/AB-5>", Completed: true},
	}

	c := plan(base+"/", issues, reminders)

	wantCreate := []newReminder{{Title: "🎫 AB-1 [In Progress]: Fix", Notes: "jira-reminders <https://x.atlassian.net/browse/AB-1>\n\n#jira"}}
	if !reflect.DeepEqual(c.Create, wantCreate) {
		t.Errorf("Create = %v, want %v", c.Create, wantCreate)
	}
	if !reflect.DeepEqual(c.Reopen, []string{"done"}) {
		t.Errorf("Reopen = %v, want [done]", c.Reopen)
	}
	if !reflect.DeepEqual(c.Complete, []string{"stale"}) {
		t.Errorf("Complete = %v, want [stale]", c.Complete)
	}
	if want := []rename{{ID: "moved", Title: "🎫 AB-6 [In Progress]: Fix"}}; !reflect.DeepEqual(c.Rename, want) {
		t.Errorf("Rename = %v, want %v", c.Rename, want)
	}
}

func TestSearchPaginates(t *testing.T) {
	var tokens []any
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if user, pass, _ := r.BasicAuth(); user != "me@x" || pass != "secret" || r.URL.Path != "/rest/api/3/search/jql" {
			http.Error(w, "bad request", http.StatusUnauthorized)
			return
		}
		var body map[string]any
		_ = json.NewDecoder(r.Body).Decode(&body)
		tokens = append(tokens, body["nextPageToken"])
		if body["nextPageToken"] == nil {
			_, _ = w.Write([]byte(`{"issues":[{"key":"AB-1"}],"nextPageToken":"p2"}`))
			return
		}
		_, _ = w.Write([]byte(`{"issues":[{"key":"AB-2"}],"isLast":true}`))
	}))
	defer server.Close()

	c := &jiraClient{baseURL: server.URL, email: "me@x", token: "secret", http: server.Client()}
	issues, err := c.search("assignee = currentUser()")
	if err != nil {
		t.Fatal(err)
	}
	if len(issues) != 2 || issues[0].Key != "AB-1" || issues[1].Key != "AB-2" {
		t.Errorf("issues = %v, want AB-1, AB-2", issues)
	}
	if want := []any{nil, "p2"}; !reflect.DeepEqual(tokens, want) {
		t.Errorf("tokens = %v, want %v", tokens, want)
	}
}

func TestNewJiraClient(t *testing.T) {
	secrets := map[string]string{"url": base + "/", "username": "me@x", "password": "secret\n"}
	get := func(service, user string) (string, error) {
		if service != "jira" {
			return "", errors.New("unknown service")
		}
		return secrets[user], nil
	}

	c, err := newJiraClient(get)
	if err != nil {
		t.Fatal(err)
	}
	if c.baseURL != base || c.email != "me@x" || c.token != "secret" {
		t.Errorf("client = %+v, want trimmed keyring values", c)
	}

	delete(secrets, "password")
	if _, err := newJiraClient(get); err == nil {
		t.Error("newJiraClient() error = nil, want an error for the missing password")
	}
}

func TestSearchError(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.Error(w, "nope", http.StatusBadRequest)
	}))
	defer server.Close()

	c := &jiraClient{baseURL: server.URL, http: server.Client()}
	if _, err := c.search("x"); err == nil {
		t.Error("search() error = nil, want an error")
	}
}
