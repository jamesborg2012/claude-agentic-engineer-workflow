# Spec: export widgets (revised)

## Acceptance criteria

1. The export button downloads a CSV with one row per widget, UTF-8 encoded.
2. An empty list produces a header-only file.
3. Exports over 10,000 rows are streamed.

```sh
curl -s '/api/widgets.csv?stream=1'
```
