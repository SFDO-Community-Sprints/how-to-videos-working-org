---
status: accepted
---

# The org is the working copy, and this repository is its backup

Volunteers build in the working org with clicks: fields, layouts, flows, reports. This repository holds one manifest that lists our components. After each working session, someone retrieves those components into the repository and commits them. Code is the exception. Lightning web components, Apex, and the prompt template start in the repository and are deployed from it.

The alternative is to build everything from source and treat the org as disposable. That suits a team of developers. This team builds at sprints, by clicks, and a rule that nobody follows produces an org and a repository that disagree.

## Consequences

- The manifest decides what belongs to this project. The working org is a Nonprofit Cloud org with its own record types, sample data, and sites, and none of that is ours to track.
- The working org is a trial that expires on 2026-12-11 unless Salesforce extends it. Until then, the repository is the only copy that is sure to survive, so a session that ends without a retrieve can lose work.
- A deploy to the working org is a deploy to a production-type org. Validate first.
