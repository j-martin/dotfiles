package main

import (
	"reflect"
	"testing"
)

func TestNameFromEmail(t *testing.T) {
	tests := map[string]string{
		"jane.doe@example.com":           "Jane Doe",
		"Jean-Martin.Archer@example.com": "Jean-Martin Archer",
		"anne.marie.smith@example.com":   "Anne Marie Smith",
		"jdoe@example.com":               "",
		"jane.doe2@example.com":          "",
		"jane.doe":                       "",
		"":                               "",
	}
	for email, want := range tests {
		if got := nameFromEmail(email); got != want {
			t.Errorf("nameFromEmail(%q) = %q, want %q", email, got, want)
		}
	}
}

func TestCoworkers(t *testing.T) {
	got := coworkers(
		[]member{
			{Login: "zed", Name: "Zed GitHub"},
			{Login: "nobody", Name: ""},
			{Login: "adoe", Name: "Alice Profile"},
		},
		[]samlIdentity{
			{Login: "zed", Email: "zed.smith@example.com"},
			{Login: "adoe", Email: "adoe@example.com"},
		},
	)
	want := []coworker{
		{Login: "zed", Email: "zed.smith@example.com", Name: "Zed Smith"},
		{Login: "nobody", Email: "", Name: "nobody"},
		{Login: "adoe", Email: "adoe@example.com", Name: "Alice Profile"},
	}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("coworkers() = %v, want %v", got, want)
	}
}

func TestCoworkerGroupSortsByDescription(t *testing.T) {
	all := []coworker{{Login: "zed", Name: "Zed Smith"}, {Login: "adoe", Name: "alice Doe"}}
	got := coworkerGroup("GitHub - Coworkers", all, func(c coworker) string { return c.Login })
	want := snippetGroup{
		Name:     "GitHub - Coworkers",
		Snippets: []snippet{{Desc: "alice Doe", Text: "adoe"}, {Desc: "Zed Smith", Text: "zed"}},
	}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("coworkerGroup() = %v, want %v", got, want)
	}
}

func TestCoworkerGroupSkipsEmptyText(t *testing.T) {
	all := []coworker{{Login: "zed", Email: "zed.smith@example.com", Name: "Zed Smith"}, {Login: "bot", Name: "bot"}}
	got := coworkerGroup("Email", all, func(c coworker) string { return c.Email })
	want := []snippet{{Desc: "Zed Smith", Text: "zed.smith@example.com"}}
	if !reflect.DeepEqual(got.Snippets, want) {
		t.Errorf("coworkerGroup().Snippets = %v, want %v", got.Snippets, want)
	}
}
