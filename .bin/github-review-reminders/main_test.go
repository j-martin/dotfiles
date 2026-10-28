package main

import (
	"reflect"
	"testing"
)

func TestNoteURL(t *testing.T) {
	tests := map[string]string{
		"github-review-reminders <https://github.com/o/r/pull/1>\n\nby a": "https://github.com/o/r/pull/1",
		"github-review-reminders <https://github.com/o/r/pull/1>":         "https://github.com/o/r/pull/1",
		"https://github.com/o/r/pull/1":                                   "",
		"github-review-reminders <https://github.com/o/r/issues/1>":       "",
		"github-review-reminders <https://github.com/o/r/pull/1/files>":   "",
		"see github-review-reminders <https://github.com/o/r/pull/1>":     "",
		"": "",
	}
	for body, want := range tests {
		if got := noteURL(body); got != want {
			t.Errorf("noteURL(%q) = %q, want %q", body, got, want)
		}
	}
}

func TestPlan(t *testing.T) {
	pr := func(url string) pullRequest {
		p := pullRequest{URL: url, Title: "Fix", Number: 1}
		p.Repository.NameWithOwner = "o/r"
		p.Author.Login = "a"
		return p
	}
	requested := []pullRequest{
		pr("https://github.com/o/r/pull/1"),
		pr("https://github.com/o/r/pull/2"),
		pr("https://github.com/o/r/pull/3"),
	}
	reminders := []reminder{
		{ID: "open", Body: "github-review-reminders <https://github.com/o/r/pull/2>\n\nby a"},
		{ID: "done", Body: "github-review-reminders <https://github.com/o/r/pull/3>", Completed: true},
		{ID: "stale", Body: "github-review-reminders <https://github.com/o/r/pull/4>"},
		{ID: "stale-done", Body: "github-review-reminders <https://github.com/o/r/pull/5>", Completed: true},
	}

	c := plan(requested, reminders)

	wantCreate := []newReminder{{Title: "👀 Review o/r#1: Fix", Notes: "github-review-reminders <https://github.com/o/r/pull/1>\n\nby a\n\n#github"}}
	if !reflect.DeepEqual(c.Create, wantCreate) {
		t.Errorf("Create = %v, want %v", c.Create, wantCreate)
	}
	if !reflect.DeepEqual(c.Reopen, []string{"done"}) {
		t.Errorf("Reopen = %v, want [done]", c.Reopen)
	}
	if !reflect.DeepEqual(c.Complete, []string{"stale"}) {
		t.Errorf("Complete = %v, want [stale]", c.Complete)
	}
}

func TestIgnoredReposQualifiers(t *testing.T) {
	got := ignoredReposQualifiers(" o/a, ,o/b")
	if want := []string{"-repo:o/a", "-repo:o/b"}; !reflect.DeepEqual(got, want) {
		t.Errorf("ignoredReposQualifiers = %v, want %v", got, want)
	}
}
