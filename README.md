# akrisanov.com

Technical writing on AI infrastructure, ML systems, distributed systems,
production LLM serving, Kubernetes, and platform reliability.

Built with [Zola](https://www.getzola.org/).

## Local Development

Install Zola if you haven't already:

```bash
brew install zola
```

Serve content with live reload:

```bash
zola serve
```

The site is available at [http://127.0.0.1:1111](http://127.0.0.1:1111).

## Talks

The `/talks/` page uses `data/talks.toml`. Each `[[entries]]` block is one
independent catalog entry with `kind` (`playlist`, `lecture`, or `interview`),
`language` (`ru` or `en`), a unique `id`, `title`, `description`, `date`,
`date_label`, and YouTube `url`. Keep entries in the desired display order;
dates describe the recordings, not their upload dates.

Playlists contain `[[entries.videos]]` blocks in viewing order, shown in an
expandable list. Videos have a `title`, `url`, optional `description`, and inherit
the playlist language unless they specify their own `language`. Standalone
lectures and interviews use the same top-level layout without a nested list.
Videos and standalone entries can include `duration`, `duration_iso` (ISO 8601),
and `duration_label` (English accessible label). The interface stays in English;
titles and descriptions keep the recording's language.

---

© Andrey Krisanov, 2024–2026
