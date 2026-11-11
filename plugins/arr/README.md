# arr

Sonarr and Radarr on a title's page in [movies](../movies): whether the title
is in your library (and how much of it is downloaded), and a button that
requests it, adding a series to Sonarr or a film to Radarr and starting a
search. Titles are matched by their IMDb id.

The button only shows for a server that is set up: Settings › Arr, or

```nix
programs.fableland.settings.arr = {
  sonarr = { url = "http://localhost:8989"; apiKeyFile = "/run/secrets/sonarr"; };
  radarr = { url = "http://localhost:7878"; apiKeyFile = "/run/secrets/radarr"; qualityProfile = "HD-1080p"; };
};
```

Prefer `apiKeyFile` to `apiKey` in a Nix configuration: whatever is in
`settings` ends up in the Nix store, readable by everyone on the machine.

## Settings

| setting | default | |
| --- | --- | --- |
| `arr.search` | `true` | search for a title as soon as it is added |
| `arr.sonarr.url`, `arr.radarr.url` | `""` | where the server answers |
| `arr.sonarr.apiKey`, `arr.radarr.apiKey` | `""` | its API key (Settings › General there) |
| `arr.sonarr.apiKeyFile`, `arr.radarr.apiKeyFile` | `""` | or a file holding the key; used when set |
| `arr.sonarr.qualityProfile`, `arr.radarr.qualityProfile` | `""` | the profile requests use, by name; empty: the first |
| `arr.sonarr.rootFolder`, `arr.radarr.rootFolder` | `""` | where requests go; empty: the first root folder |

## Methods

`type` (`movie` or `series`) picks the server, or `service` (`sonarr` or `radarr`) names it.

- `arr.lookup {id, title?, type}` → `{ service, name, found, title, inLibrary, monitored, have, link }`:
  `have` is the per cent downloaded, `link` the title's page on the server. `found` is false for a title the server does not know.
- `arr.request {id, title?, type}` → the same, once the title is added (nothing happens to one already there).
- `arr.test {service}` → `{ version, profile, rootFolder }`: what a request would use.

The topic `arr` is `{ sonarr, radarr }`: which of the two are set up.

Tested against a stand-in for the Sonarr 4 and Radarr 5 APIs, not a real server yet.
