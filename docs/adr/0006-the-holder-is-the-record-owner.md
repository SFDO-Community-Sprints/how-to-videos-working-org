---
status: accepted
---

# The holder of content is the record's owner

The charter makes the org "the official record for which a volunteer holds custody of a given video project". We record custody in the standard Owner field of `HowToContent__c`, with field history on Owner and Status. There is no custody object. Handing content over is a change of owner, and the history list is the custody record. "My content" views and task assignment work with no extra setup.

The alternative is a lookup to a person record that needs no login. Any volunteer could then hold content without a license. It gives up task assignment, "my work" views, and notifications for those volunteers.

## Consequences

- Every volunteer who holds content needs a licensed internal user. See `docs/salesforce-asks.md` for the number of seats.
- A Salesforce queue owns content that nobody holds yet. Content that triage has just created starts there.
