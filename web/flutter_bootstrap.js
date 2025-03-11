{{flutter_js}}
{{flutter_build_config}}

// Configure the Flutter loader to properly initialize the application
_flutter.loader.load({
  config: {
    renderer: "canvaskit",
  }
}); 