package main

import (
	"reflect"
	"testing"
)

func TestZoneGroupsKeepsCanadaAndUS(t *testing.T) {
	const url = "https://www.googleapis.com/compute/v1/projects/p/regions/"
	zones := []gcpZone{
		{Name: "us-east4-b", Region: url + "us-east4"},
		{Name: "us-east4-a", Region: url + "us-east4"},
		{Name: "northamerica-northeast1-a", Region: url + "northamerica-northeast1"},
		{Name: "northamerica-south1-a", Region: url + "northamerica-south1"},
		{Name: "europe-west1-b", Region: url + "europe-west1"},
		{Name: "us-new9-a", Region: url + "us-new9"},
	}
	regions, zoneGroup := zoneGroups(zones)
	wantRegions := snippetGroup{
		Name: "GCP - Region",
		Snippets: []snippet{
			{Desc: "Ashburn, Virginia (us-east4)", Text: "us-east4"},
			{Desc: "Montréal, Québec (northamerica-northeast1)", Text: "northamerica-northeast1"},
			{Desc: "us-new9", Text: "us-new9"},
		},
	}
	wantZones := snippetGroup{
		Name: "GCP - Zone",
		Snippets: []snippet{
			{Desc: "Ashburn, Virginia (us-east4-a)", Text: "us-east4-a"},
			{Desc: "Ashburn, Virginia (us-east4-b)", Text: "us-east4-b"},
			{Desc: "Montréal, Québec (northamerica-northeast1-a)", Text: "northamerica-northeast1-a"},
			{Desc: "us-new9-a", Text: "us-new9-a"},
		},
	}
	if !reflect.DeepEqual(regions, wantRegions) {
		t.Errorf("regions = %v, want %v", regions, wantRegions)
	}
	if !reflect.DeepEqual(zoneGroup, wantZones) {
		t.Errorf("zones = %v, want %v", zoneGroup, wantZones)
	}
}
