package main

import (
  "fmt"
  "github.com/spf13/pflag"
  "github.com/zalando/go-keyring"
  "log"
  ga "saml.dev/gome-assistant"
  "strings"
)

func main() {
  err := run()
  if err != nil {
    log.Fatal(err)
  }
}

func run() error {
  var scene = pflag.BoolP("scene", "s", false, "Scene to turn on")
  pflag.Parse()
  authToken, err := keyring.Get("system", "homeassistant")
  if err != nil {
    return fmt.Errorf("failed to get homeassistant auth token: %w", err)
  }
  app, _ := ga.NewApp(ga.NewAppRequest{
    URL:              "https://assistant.home.jmartin.ca/",
    HAAuthToken:      authToken,
    HomeZoneEntityId: "zone.home",
  })

  if !*scene {
    return fmt.Errorf("only --scene is supported")
  }

  if len(pflag.Args()) == 0 {
    return fmt.Errorf("scene name is required")
  }

  entityId := fmt.Sprintf("scene.%s", strings.Join(pflag.Args(), "_"))
  err = app.GetService().Scene.TurnOn(entityId)
  if err != nil {
    return fmt.Errorf("failed to turn on scene: %w", err)
  }

  return nil
}
