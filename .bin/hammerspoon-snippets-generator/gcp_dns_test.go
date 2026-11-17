package main

import (
	"errors"
	"reflect"
	"testing"
)

func TestDNSProjectsMatchesIDOrNameIgnoringCase(t *testing.T) {
	projects := []gcpProject{
		project("acme-dns-123", "Acme", "organization", "1"),
		project("acme-net", "Shared DNS", "organization", "1"),
		project("acme-web", "Web", "organization", "1"),
	}
	want := []string{"acme-dns-123", "acme-net"}
	if got := dnsProjects(projects); !reflect.DeepEqual(got, want) {
		t.Errorf("dnsProjects() = %v, want %v", got, want)
	}
}

func TestDNSRecordGroupListsTypesPerFQDN(t *testing.T) {
	got := dnsRecordGroup([]gcpDNSRecord{
		{Name: "example.com.", Type: "TXT"},
		{Name: "www.example.com.", Type: "CNAME"},
		{Name: "example.com.", Type: "A"},
		{Name: "example.com.", Type: "A"},
	})
	want := snippetGroup{
		Name: "GCP - DNS Record",
		Snippets: []snippet{
			{Desc: "example.com (A, TXT)", Text: "example.com"},
			{Desc: "www.example.com (CNAME)", Text: "www.example.com"},
		},
	}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("dnsRecordGroup() = %v, want %v", got, want)
	}
}

func TestConcurrentMapKeepsOrder(t *testing.T) {
	got, err := concurrentMap([]int{1, 2, 3}, 2, func(i int) (int, error) { return i * 10, nil })
	if err != nil {
		t.Fatal(err)
	}
	if want := []int{10, 20, 30}; !reflect.DeepEqual(got, want) {
		t.Errorf("concurrentMap() = %v, want %v", got, want)
	}
}

func TestConcurrentMapReturnsErrors(t *testing.T) {
	_, err := concurrentMap([]int{1, 2}, 2, func(i int) (int, error) {
		if i == 2 {
			return 0, errors.New("denied")
		}
		return i, nil
	})
	if err == nil {
		t.Error("concurrentMap() error = nil, want denied")
	}
}
