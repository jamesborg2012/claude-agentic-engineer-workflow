<!--
Artefact: .aew/runs/<run-id>/09-triage-<n>.md
Written by: senior-engineer (triage mode), for plan_divergence or test_bug failures, or an impl_bug the developer didn't fix in one cycle
Read by: developer (fix mode), qa-engineer (when a test is ruled wrong), orchestrator (routing)
-->
# Triage <n>: #<issue> <title>

QA report: 08-qa-report-<n>.md. Failures triaged: <TC>, <TC>

## Root cause

## Where the divergence started

spec / brief / plan / implementation

## Fix instructions

<!-- For the developer. Leave as "None." when the ruling is that a test is wrong. -->

## Test ruling

<!-- "None." or: which test is wrong, why, and instructions for QA. -->

<!-- Return block (DESIGN §7.5). -->
STATUS: ok | needs_input | blocked | failed
ARTEFACTS: .aew/runs/<run-id>/09-triage-<n>.md
SUMMARY: <≤150 words>
NEXT: <developer (fix mode) or qa-engineer>
