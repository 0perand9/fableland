# movies

A film and series catalogue from Cinemeta (the public Stremio metadata
service): what is trending, a search, a title's details with its seasons and
episodes, and a button that opens the title with a link of your choosing.
Nothing is played here. `fable toggle movies` opens it.

## Settings

| setting | default | |
| --- | --- | --- |
| `movies.openWith` | JustWatch search | link template: `{title}` `{id}` `{type}` `{season}` `{episode}` |

## Methods

`type` is `movie` or `series`.

- `movies.trending {type}` / `movies.search {query, type}` → `[{ id, title, poster, year, rating, type }]`
- `movies.details {id, type}` → `{ id, type, title, description, poster, background, year, rating, runtime, genres, cast, episodes: [{ season, episode, title }] }`
- `movies.history` → `{ searches: ["…"], watched: [{ id, title, poster, type }] }`
- `movies.rememberSearch {query}` → history (searches are not remembered by themselves), `movies.forgetSearch {query}` → history
- `movies.open {id, title, poster?, type, season?, episode?}` → history (opens the `movies.openWith` link)

## Slot

`movies.details.actions`, beside a title's Open button. `context` is
`{ title, details, hue }`: `title` as in the lists (`id` is the IMDb id),
`details` as `movies.details` returns it (null while it loads), `hue` the colour
of the page. The [arr](../arr) plugin puts its Request button there.
