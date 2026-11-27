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

func is(key, status string) issue {
	i := issue{Key: key}
	i.Fields.Summary = "Fix"
	i.Fields.Status.Name = status
	return i
}

func TestPlan(t *testing.T) {
	issues := []issue{is("AB-1", "In Progress"), is("AB-2", "In Progress"), is("AB-3", "In Progress"), is("AB-6", "In Progress"), is("AB-7", "In Progress")}
	reminders := []reminder{
		{ID: "open", Name: "🎫 AB-2 [In Progress]: Fix", Body: "jira-reminders <https://x.atlassian.net/browse/AB-2>\n\n#jira"},
		{ID: "auto-done", Name: "🎫 AB-3 [In Progress]: Fix", Body: "jira-reminders <https://x.atlassian.net/browse/AB-3>\n\n" + autoCompleted, Completed: true},
		{ID: "moved", Name: "🎫 AB-6 [To Do]: Fix", Body: "jira-reminders <https://x.atlassian.net/browse/AB-6>"},
		{ID: "user-done", Name: "🎫 AB-7 [To Do]: Fix", Body: "jira-reminders <https://x.atlassian.net/browse/AB-7>", Completed: true},
		{ID: "stale", Body: "jira-reminders <https://x.atlassian.net/browse/AB-4>\n\n#jira"},
		{ID: "stale-done", Body: "jira-reminders <https://x.atlassian.net/browse/AB-5>", Completed: true},
	}

	c := plan(base+"/", issues, reminders)

	wantCreate := []newReminder{{Title: "🎫 AB-1 [In Progress]: Fix", Notes: "jira-reminders <https://x.atlassian.net/browse/AB-1>\n\n#jira", URL: "https://x.atlassian.net/browse/AB-1"}}
	if !reflect.DeepEqual(c.Create, wantCreate) {
		t.Errorf("Create = %v, want %v", c.Create, wantCreate)
	}
	if want := []renote{{ID: "auto-done", Notes: "jira-reminders <https://x.atlassian.net/browse/AB-3>"}}; !reflect.DeepEqual(c.Reopen, want) {
		t.Errorf("Reopen = %v, want %v", c.Reopen, want)
	}
	if want := []renote{{ID: "stale", Notes: "jira-reminders <https://x.atlassian.net/browse/AB-4>\n\n#jira\n\n" + autoCompleted}}; !reflect.DeepEqual(c.Complete, want) {
		t.Errorf("Complete = %v, want %v", c.Complete, want)
	}
	if want := []rename{{ID: "moved", Title: "🎫 AB-6 [In Progress]: Fix", URL: "https://x.atlassian.net/browse/AB-6"}}; !reflect.DeepEqual(c.Rename, want) {
		t.Errorf("Rename = %v, want %v", c.Rename, want)
	}
}

func TestPlanTransitions(t *testing.T) {
	issues := []issue{is("AB-1", "To Do"), is("AB-2", "To Do"), is("AB-3", "To Do"), is("AB-4", "In Progress"), is("AB-5", "To Do"), is("AB-6", "To Do")}
	reminders := []reminder{
		{Name: "🎫 AB-1 [To Do]: Fix", Body: "jira-reminders <https://x.atlassian.net/browse/AB-1>", Completed: true},
		{Name: "🎫 AB-2 [To Do]: Fix", Body: "jira-reminders <https://x.atlassian.net/browse/AB-2>\n\n" + autoCompleted, Completed: true},
		{Name: "🎫 AB-3 [To Do]: Fix p ", Body: "jira-reminders <https://x.atlassian.net/browse/AB-3>"},
		{Name: "🎫 AB-4 [In Progress]: Fix p", Body: "jira-reminders <https://x.atlassian.net/browse/AB-4>"},
		{Name: "🎫 AB-5 [To Do]: Fix map", Body: "jira-reminders <https://x.atlassian.net/browse/AB-5>"},
		{Name: "🎫 AB-9 [To Do]: Fix", Body: "jira-reminders <https://x.atlassian.net/browse/AB-9>", Completed: true},
	}

	got := planTransitions(base, issues, reminders)

	want := []transitionRequest{{Key: "AB-1", Target: statusDone}, {Key: "AB-3", Target: statusInProgress}}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("planTransitions() = %v, want %v", got, want)
	}
}

func TestWithoutAutoCompletedRevertsWithAutoCompleted(t *testing.T) {
	body := "jira-reminders <https://x.atlassian.net/browse/AB-1>\n\n#jira"
	if got := withoutAutoCompleted(withAutoCompleted(body)); got != body {
		t.Errorf("withoutAutoCompleted(withAutoCompleted(%q)) = %q", body, got)
	}
}

func TestPickTransition(t *testing.T) {
	transition := func(id, name, category string) jiraTransition {
		var tr jiraTransition
		tr.ID = id
		tr.To.Name = name
		tr.To.StatusCategory.Key = category
		return tr
	}
	transitions := []jiraTransition{transition("1", "In progress", "indeterminate"), transition("2", "Won't Do", "done"), transition("3", "Done", "done")}
	tests := []struct {
		transitions []jiraTransition
		target      string
		want        string
	}{
		{transitions, statusInProgress, "1"},
		{transitions, statusDone, "3"},
		{transitions[:2], statusDone, "2"},
		{transitions[1:], statusInProgress, ""},
	}
	for _, tt := range tests {
		got := ""
		if tr := pickTransition(tt.transitions, tt.target); tr != nil {
			got = tr.ID
		}
		if got != tt.want {
			t.Errorf("pickTransition(%v, %q) = %q, want %q", tt.transitions, tt.target, got, tt.want)
		}
	}
}

func TestTransitionTo(t *testing.T) {
	var posted map[string]any
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/rest/api/3/issue/AB-1/transitions" {
			http.NotFound(w, r)
			return
		}
		if r.Method == http.MethodGet {
			_, _ = w.Write([]byte(`{"transitions":[{"id":"11","to":{"name":"To Do"}},{"id":"21","to":{"name":"In Progress"}}]}`))
			return
		}
		_ = json.NewDecoder(r.Body).Decode(&posted)
		w.WriteHeader(http.StatusNoContent)
	}))
	defer server.Close()

	c := &jiraClient{baseURL: server.URL, http: server.Client()}
	if err := c.transitionTo("AB-1", statusInProgress); err != nil {
		t.Fatal(err)
	}
	if want := map[string]any{"transition": map[string]any{"id": "21"}}; !reflect.DeepEqual(posted, want) {
		t.Errorf("posted = %v, want %v", posted, want)
	}
	if err := c.transitionTo("AB-1", statusDone); err == nil {
		t.Error("transitionTo() error = nil, want an error without a Done transition")
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
