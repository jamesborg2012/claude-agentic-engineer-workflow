<!-- aew:spec v2 -->
# Spec: export widgets

## Acceptance criteria

1. The export button downloads a CSV with one row per widget.
2. An empty list produces a header-only file.

```sh
curl -s /api/widgets.csv
```

<!-- /aew:spec -->

<!-- aew:spec-prev v1 -->
<details>
<summary>Spec v1 (original)</summary>

# Export widgets to CSV

Users want a café-style “export” — with an emoji 🚀 — for the widget list.  
This line ends with two spaces (a Markdown line break).
	This line is indented with a tab.

<!-- author note -->

<!--
A multi-line author comment.
It must survive untouched.
-->

- Top level
  - Nested item one
  - Nested item two
    - Deeper

| Column | Meaning |
|--------|---------|
| id     | widget id |
| name   | widget name |

<details><summary>Logs</summary>

```
error: boom
```

</details>

```html
<details>
<summary>Not a real block</summary>
--> still inside the fence
</details>
```

Thanks — Sam


</details>
<!-- /aew:spec-prev v1 -->
