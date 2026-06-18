# Installation

> The SDK is **server-only**. Place it and your API key in `ServerStorage` or
> `ServerScriptService` — never in a client-replicated container.

## Prerequisites

- HTTP requests enabled: Studio → Game Settings → Security → *Allow HTTP Requests*.
- An API key: RoControl dashboard → your game → SDK → API Keys → Create.

## Option A — Wally

```toml
# wally.toml
[dependencies]
RoControl = "gh-constant/rocontrol-roblox-sdk@0.2.1"
```

```sh
wally install
```

It's a normal `shared` package, so it installs into your usual `Packages` folder
(typically mapped to `ReplicatedStorage.Packages`) — the same place as every other
dependency, no special Rojo mapping needed.

## Option B — Model file (`.rbxm` / `.rbxmx`)

1. Download `RoControl.rbxm` from the [latest release](https://github.com/Badacord/rocontrol-sdk/releases).
2. Studio → right-click **ReplicatedStorage** → **Insert from File** → select the file.
3. Verify the module is where the server can require it (e.g. `ReplicatedStorage.Packages.RoControl`).

## Option C — Source / Rojo

```sh
git clone https://github.com/Badacord/rocontrol-sdk
cd rocontrol-sdk
rokit install
wally install
rojo serve            # sync into Studio
# or build a model:
rojo build default.project.json --output RoControl.rbxm
```

## Place the API key and bootstrap

1. Create `ServerStorage/RoControlConfig` (a `Folder`).
2. Inside it, create `ApiKey` (a `StringValue`) and paste your key.
3. Create `ServerScriptService/RoControlBootstrap.server.luau` (see
   [Quickstart](quickstart.md)).

> ⚠️ Keep `RoControlConfig` / `ApiKey` in `ServerStorage` and only call `init()`
> from a server script. The SDK module itself can live in
> `ReplicatedStorage.Packages` — it's inert on the client.

## Updating

- **Wally:** bump the version in `wally.toml`, run `wally install`.
- **Model file:** delete the old `RoControl` module, insert the new `.rbxm`.
