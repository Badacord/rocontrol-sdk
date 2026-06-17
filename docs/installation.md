# Installation

> The SDK is **server-only**. Place it and your API key in `ServerStorage` or
> `ServerScriptService` — never in a client-replicated container.

## Prerequisites

- HTTP requests enabled: Studio → Game Settings → Security → *Allow HTTP Requests*.
- An API key: RoControl dashboard → your game → SDK → API Keys → Create.

## Option A — Wally

```toml
# wally.toml
[server-dependencies]
RoControl = "rocontrol/rocontrol-roblox-sdk@0.1.0"
```

```sh
wally install
```

Rojo mapping (so the package stays server-side):

```json
{
  "ServerScriptService": {
    "$className": "ServerScriptService",
    "Packages": { "$path": "ServerPackages" }
  }
}
```

## Option B — Model file (`.rbxm` / `.rbxmx`)

1. Download `RoControl.rbxm` from the [latest release](https://github.com/Badacord/rocontrol-sdk/releases).
2. Studio → right-click **ServerStorage** → **Insert from File** → select the file.
3. Verify the module is at `ServerStorage/RoControl`.

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

> ⚠️ Do not put `RoControlConfig`, `ApiKey`, or the SDK under `ReplicatedStorage`,
> `StarterPlayer`, `StarterGui`, or `Workspace`. The SDK warns if it detects this.

## Updating

- **Wally:** bump the version in `wally.toml`, run `wally install`.
- **Model file:** delete `ServerStorage/RoControl`, insert the new `.rbxm`.
