// GCP regions and zones of North America, Canada and the US, from a single `gcloud compute zones list`, the regions
// being derived from the zones. The location of a region, missing from gcloud, comes from gcpRegionLocations.
package main

import (
	"encoding/json"
	"fmt"
	"path"
	"strings"
)

const (
	gcpRegionsGroupName = "GCP - Region"
	gcpRegionsFile      = "gcp-regions.json"
	gcpZonesGroupName   = "GCP - Zone"
	gcpZonesFile        = "gcp-zones.json"
)

// gcpRegionPrefixes are the prefixes of the region names of Canada and the US, excluding e.g. northamerica-south1 in Mexico.
var gcpRegionPrefixes = []string{"us-", "northamerica-northeast"}

// gcpRegionLocations are the locations of the regions, see https://cloud.google.com/compute/docs/regions-zones.
var gcpRegionLocations = map[string]string{
	"northamerica-northeast1": "Montréal, Québec",
	"northamerica-northeast2": "Toronto, Ontario",
	"us-central1":             "Council Bluffs, Iowa",
	"us-east1":                "Moncks Corner, South Carolina",
	"us-east4":                "Ashburn, Virginia",
	"us-east5":                "Columbus, Ohio",
	"us-south1":               "Dallas, Texas",
	"us-west1":                "The Dalles, Oregon",
	"us-west2":                "Los Angeles, California",
	"us-west3":                "Salt Lake City, Utah",
	"us-west4":                "Las Vegas, Nevada",
}

type gcpZone struct {
	Name string `json:"name"`
	// Region is the region URL, e.g. https://www.googleapis.com/compute/v1/projects/p/regions/us-central1.
	Region string `json:"region"`
}

func listZones() ([]gcpZone, error) {
	out, err := run("gcloud", "compute", "zones", "list", "--format=json(name,region)")
	if err != nil {
		return nil, err
	}
	var zones []gcpZone
	if err := json.Unmarshal(out, &zones); err != nil {
		return nil, fmt.Errorf("decoding the zones: %w", err)
	}
	return zones, nil
}

// isNorthAmerican reports whether region is in Canada or the US.
func isNorthAmerican(region string) bool {
	for _, prefix := range gcpRegionPrefixes {
		if strings.HasPrefix(region, prefix) {
			return true
		}
	}
	return false
}

// locationDesc returns the description of a region or zone name, e.g. Ashburn, Virginia (us-east4-a), the name
// alone when the location of the region is unknown.
func locationDesc(region, name string) string {
	if location, found := gcpRegionLocations[region]; found {
		return location + " (" + name + ")"
	}
	return name
}

// zoneGroups returns the groups of the North American regions and zones, their name as text.
func zoneGroups(zones []gcpZone) (regions, zoneGroup snippetGroup) {
	var regionSnippets, zoneSnippets []snippet
	seen := map[string]bool{}
	for _, zone := range zones {
		region := path.Base(zone.Region)
		if !isNorthAmerican(region) {
			continue
		}
		zoneSnippets = append(zoneSnippets, snippet{Desc: locationDesc(region, zone.Name), Text: zone.Name})
		if !seen[region] {
			seen[region] = true
			regionSnippets = append(regionSnippets, snippet{Desc: locationDesc(region, region), Text: region})
		}
	}
	return newGroup(gcpRegionsGroupName, regionSnippets), newGroup(gcpZonesGroupName, zoneSnippets)
}

// generateGCPZones writes the North American regions and zones to dir.
func generateGCPZones(dir string) error {
	zones, err := listZones()
	if err != nil {
		return err
	}
	regions, zoneGroup := zoneGroups(zones)
	if len(regions.Snippets) == 0 {
		return fmt.Errorf("no North American zones visible to the gcloud account")
	}
	if err := write(dir, gcpRegionsFile, regions); err != nil {
		return err
	}
	return write(dir, gcpZonesFile, zoneGroup)
}
