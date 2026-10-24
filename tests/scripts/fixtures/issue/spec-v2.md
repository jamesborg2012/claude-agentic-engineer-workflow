# Spec: export widgets

## Acceptance criteria

1. The export button downloads a CSV with one row per widget.
2. An empty list produces a header-only file.

```sh
curl -s /api/widgets.csv
```
