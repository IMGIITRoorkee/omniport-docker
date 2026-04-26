# Noticeboard

App-level configuration for the noticeboard.

Folder contents:
- `elasticsearch_stencil.env`: Template for the Elasticsearch connection settings consumed by the noticeboard search code. Copy to `elasticsearch.env` and fill in the values for the target environment.

## Description

The noticeboard app uses Elasticsearch as a secondary search index. PostgreSQL remains the source of truth for notices; the index can be torn down and rebuilt at any time via `python manage.py search_index --rebuild`.

In **production**, run Elasticsearch on a separate host so the noticeboard application server is not loaded with the index workload. Point `ELASTICSEARCH_HOST` at the private endpoint of that host and enable TLS + basic auth.

In **development**, an Elasticsearch sidecar can be started inside the same Docker Compose project. See `docker-compose.override.yml.example` in the repository root.
