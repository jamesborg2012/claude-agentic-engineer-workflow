# Standards for this run: #201 Add to basket

## Standards docs

| Profile | Doc | Fingerprint | Status |
|---|---|---|---|
| web | docs/standards/web.md | web serve@14 cfg:5f3c9a1e7b20 | reused |

## Sections that apply

| Doc | Section | Why it applies |
|---|---|---|
| docs/standards/web.md | Accessibility | AC-2: the icon-only basket button needs an accessible name, and the page targets WCAG 2.2 AA |
| docs/standards/web.md | Framework conventions | AC-1: how the page script updates the status text |
| docs/standards/web.md | Testing conventions | All ACs: unit test and Playwright spec naming and locations |

STATUS: ok
ARTEFACTS: .aew/runs/951/03-standards.md, docs/standards/README.md, docs/standards/web.md
SUMMARY: Reused the existing web standards (fingerprint unchanged). Accessibility applies to AC-2, Framework conventions to AC-1, Testing conventions to every AC.
NEXT: qa_test_plan and plan
