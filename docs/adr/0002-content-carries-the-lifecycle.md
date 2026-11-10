---
status: accepted
---

# Content carries the lifecycle, and a request closes at triage

The first request that qualifies creates a content record with the status Submitted. One Status field then carries that record through the charter's stages to Published. A request points to its content through a lookup, and many requests can point to one content record. Once a request is linked and the requester has an answer, the request is closed.

This is the flow that the team drew on 2026-11-09: new case, qualify, check whether content exists, then either link to it or draft a new record from the case.

## Considered options

**The request is the idea.** The first design made the request the public record that people vote on, and created content only when leadership accepted the idea. Two requests for the same thing then needed a merge action that moved votes from one to the other. In the chosen design a duplicate is one more link, and nothing moves.

**Content exists before any request.** The team would decide what to make, and requests would be filed under it. That reverses the point of asking the community.

## What the chosen design buys

- A person who asks for content that already exists gets the link back.
- The status list on content matches the charter's seven stages on one record.
- A Case does a Case's job. It is open for days, not for the months that production takes.

It gives up a tidy content list. Content records exist for ideas that leadership never accepts, and their status says so: Submitted or Declined.

## Consequences

- The link is a lookup, not master-detail. Salesforce does not allow a standard object on the detail side. Roll-ups from requests to content use Declarative Lookup Rollup Summaries (DLRS).
- A request is Qualified if and only if it points to content. A content record that requests point to cannot be deleted.
- Rules on content depend on its status. The Drive folder and the three artifacts are required only in the production statuses. A champion is required before Accepted. A team response is required to decline.
- Content moves forward one status at a time from Drafting onward, and back any distance.
- The charter ends at Final Review. Published and Retired are our additions and need the team's agreement at a convening.
- One idea that needs a series becomes one content record for each part.
