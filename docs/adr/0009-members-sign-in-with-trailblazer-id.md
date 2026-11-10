---
status: proposed
---

# Members sign in with Trailblazer ID, and nothing else

When the public site lets people vote, Trailblazer ID is the only way to sign in. A member is one Trailblazer ID. Each member gets a person account and a member-based Customer Community license. The member's public name comes from their Trailblazer profile.

Proposed, not accepted. It needs Salesforce to register the site as a client of the Trailblazer ID provider, and Salesforce publishes no process for that. See `docs/salesforce-asks.md`.

## Why one method

One method needs no logic to reconcile several, and a person's email address can change while their Trailblazer ID does not. The Trailblazer Community now lives in Slack and signs people in with Trailblazer ID, so the audience already has one.

Trailblazer ID is an ordinary OpenID Connect provider at `https://iis.digital.salesforce.com`. Its discovery document lists the authorization code flow, the scopes `openid`, `email`, and `profile`, and the claims `sub`, `email_verified`, and `name`.

It proves control of an account and nothing more. One person can hold several Trailblazer IDs. We accept that, because votes inform the priority queue and people decide it.

## Why person accounts and this license

Anyone with a Trailblazer ID can sign in, so we plan for more than 10,000 members.

- **One shared account for all members** runs into Salesforce's own guidance, which says performance starts to degrade at about 10,000 child records under one parent.
- **Customer Community Plus** adds roles, sharing rules, and reports for members. Members would use none of them, and one owner can hold only 50,000 person-account site users.
- **Customer Community** has no roles. Salesforce describes it for "business-to-consumer experiences with large numbers of external users" and lists it at more than 100 million users.

These points come from Salesforce documentation read in November 2026. Nothing was tested at that scale.

## Consequences

- Person accounts are already on in the working org, because Nonprofit Cloud uses them.
- A dedicated system user owns the member accounts. Salesforce requires that owner to have a role.
- An internal user who also signs in to the site stays one person. Their Trailblazer ID is linked to their existing user.
- The sign-in page is Salesforce's. We can test it with a screen reader, and we cannot fix it.
- A public voting status is added between Submitted and Accepted.
