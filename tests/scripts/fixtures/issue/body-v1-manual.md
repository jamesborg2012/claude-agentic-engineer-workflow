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


<!-- aew:manual-tests -->
## Manual testing required

- [ ] **TC-1 (AC-1):** Open the widget list and click Export → a CSV downloads. _Why manual:_ browser download dialog.
- [ ] **TC-2 (AC-2):** Export an empty list → only the header row is present. _Why manual:_ needs an empty production-like dataset.

<!-- /aew:manual-tests -->
