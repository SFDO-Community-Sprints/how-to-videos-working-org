---
status: proposed
---

# The public site is an LWR site, and visitors read content through sharing

Round 2 adds a public site where visitors see the priority queue and published content. It uses the Build Your Own (LWR) template with our own Lightning web components. We own every element of the markup, which lets us hold the site to WCAG 2.2 AA and test it with NVDA and JAWS. The Aura templates give record lists and detail pages with markup that we could not fix.

Visitors read `HowToContent__c` through a guest sharing rule and field-level security. The rule exposes content from Accepted onward. A field is private unless we publish it, and the platform enforces that.

Proposed, not accepted. Round 1 has no site, and nobody has yet created a guest sharing rule on this object.

## Considered options

**An Apex read service that runs in system mode.** An earlier design used one, when the public record was a Case. Case would have needed guest access on an object that also holds private records, and member access to every Account. Content is a custom object with none of those problems, so sharing is the simpler route and the one Salesforce recommends for guest users.

## Consequences

- Guests hold no access to Case.
- Record pages, lists, and search on the site are ours to build and keep accessible.
- The first step of round 2 is to prove one guest sharing rule with a real deploy.
