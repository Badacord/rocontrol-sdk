# Public Roadmap

The SDK ships in phases. Each phase is independently useful.

- **Phase 1 — Foundation & transport** ✅ *(this release)*
  init, config validation, typed errors, logging + redaction, metrics, HTTP stack
  (routes, classifier, retry, circuit breaker), bounded queue, client lifecycle
  (`flush`/`destroy`/failure callback/health), engine adapters, pure-logic tests,
  CI, docs.
- **Phase 2 — Declarative schedules**
  Canonical JSON, content-hash versioning, sequential descriptors, registry scan,
  adapters, golden fixtures.
- **Phase 3 — Backend resolver**
  Multi-source resolver, decision trace, change-only icon writes. *(RoControl backend.)*
- **Phase 4 — Imperative reporting**
  `reportEvent` with MemoryStore single-flight lease and backend idempotency.
- **Phase 5 — Asset & moderation hardening** ✅ *(backend integration)*
  Asset-id normalization, Roblox thumbnail/image resolution, caching, moderation
  surfacing, and SDK moderation metrics.
- **Phase 6 — Distribution polish**
  Wally publish, release artifacts, docs site generator (VitePress/Docusaurus),
  RoControl docs cross-links.
- **Backlog — Studio plugin**
  One-click install into ServerStorage with secret-placement guards.

## Docs site

Docs are plain Markdown today and published to GitHub Pages via
`.github/workflows/docs.yml`. A static-site generator (VitePress or Docusaurus)
will be added in Phase 6.
