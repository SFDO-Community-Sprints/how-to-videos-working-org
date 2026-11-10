---
status: accepted
---

# A request is a Case, and content is a custom object

A request is a standard Case with its own record type, Video Request. The thing the team makes is a custom object, `HowToContent__c`. A vote is a custom object, `Vote__c`. We do not use the standard Ideas feature.

The project lead chose Cases, and a request does behave like a case. It arrives from a named person, someone triages it, the person gets an answer, and it closes. Cases also bring features that round 1 uses as they ship: Web-to-Case, auto-response rules, assignment rules, queues, and email templates.

## Considered options

**The standard Ideas feature (`Idea`, `Vote`).** We rejected it on evidence from a Developer Edition org at API 68.0, using anonymous Apex that rolled itself back on 2026-11-09:

- A vote cannot be withdrawn. Deleting your own vote fails with "insufficient access rights on object id".
- A vote cannot be changed. Updating `Vote.Type` fails with "UPDATE not supported for vote with non-Knowledge parent entity".
- Ideas cannot be merged through the API. `ParentIdeaId` is "not editable".

Salesforce documents the feature as "Available in: Salesforce Classic" (Ideas Implementation Guide, Spring '24).

**A custom object for requests.** The first design used one. It allows cheaper licenses, because the Salesforce Platform license excludes Cases. It gives up every Case feature listed above. We set it aside when the lead chose Cases and license cost stopped being a constraint.

## Consequences

- Every team member who triages or reads requests needs a full Salesforce license, not a Platform license.
- The working org already uses Case for Nonprofit Cloud, with the record types Client Engagement and Support Request and six statuses. The Video Request record type has its own support process so that our three statuses stay separate: New, Qualified, and Not Qualified.
- A record type's status list limits the picklist on screen. It does not stop Apex or the API from writing another status. A validation rule holds a Video Request to its three statuses. We saw this in a check-only deploy with Apex tests in the Developer Edition org.
- Case ignores "required" and "unique" on `Subject`. A validation rule requires a title on a Video Request. The same check-only deploy showed this.
- Native Case merge stays off. Two requests for the same thing both point to one content record. See ADR 0002.
- A request has no Contact and no Account. The requester's name and email address sit in the Case's web fields.
