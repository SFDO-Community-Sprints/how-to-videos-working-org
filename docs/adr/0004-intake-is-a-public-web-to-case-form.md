---
status: accepted
---

# Intake is a public Web-to-Case form with no sign-in

Anyone can ask for content through a plain HTML form that posts to Web-to-Case. The form asks for a name, an email address, a title, a description, a product, and a feature. Nobody signs in. An assignment rule puts the new Case in the triage queue, and an auto-response rule emails the requester.

The form is one page in this repository, published with GitHub Pages. The markup is ours, so its accessibility is ours to get right.

## Considered options

**A form on an Experience Cloud site that members sign in to use.** The first design had this, with an Apex service that created the record. It gives a verified identity for every request. It costs a site, a sign-in method, licenses for members, and custom components, all before the first request can arrive. We dropped it for round 1 because of what changed in ADR 0002. A request is no longer public and no longer something people vote on, so it needs less protection. Nothing a requester types is seen outside the team until triage qualifies it.

## What this gives up

- The email address is not verified. Request Count can be inflated by someone who types different addresses. See ADR 0003.
- There is no CAPTCHA. A checkbox CAPTCHA is a known barrier for screen reader users. Spam reaches the triage queue, and the Queue Manager closes it as Not Qualified.

## Consequences

- The form says that the requester's name can be shown with the idea if the team accepts it.
- The form sets the record type and the origin through hidden fields. We have not yet tested this in the working org.
- The requester hears from the team by email: on receipt, at triage, and when the content is published. A requester has no login, so a Chatter post or a Case comment would not reach them.
- Requests that team members enter by hand, and requests that are imported, use the same record type with a different origin. The origins are Community, Comms, Internal, and Import.
- Publishing the form needs a repository admin to turn on GitHub Pages.
