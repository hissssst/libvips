# Libvips

Elixir bindings for libvips. Open an issue if you want to use it

## Installation

```elixir
def deps do
  [
    {:libvips, github: "hissssst/libvips"}
  ]
end
```

## Configuration

```elixir
config :libvips, vips_executable: "path/to/vips"
config :libvips, vipsheader_executable: "path/to/vipsheader"
```
