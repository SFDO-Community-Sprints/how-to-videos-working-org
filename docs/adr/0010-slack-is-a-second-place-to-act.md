---
status: proposed
---

# Slack is a second place to act, and the site stays complete

The Trailblazer Community moved to Slack in late 2026. In later rounds, the team's Slack app posts each piece of public content to a channel, and that post's thread is where people discuss it and where status changes are announced. Later still, people can ask for content and vote from Slack. The public site remains the only place to browse, sort, and filter.

Proposed, not accepted. It needs an administrator of the Trailblazers Slack organisation to approve and deploy the app.

## Considered options

**Slack as the only place to act.** The site would be read-only for everyone. It is the smallest design, because it removes site sign-in. We did not take it. A public site that cannot be used without joining Slack is not like IdeaExchange, and Slack's markup is not ours to make accessible.

**Apex as the Slack app's backend.** Salesforce's Apex SDK for Slack has been in beta since 2022, with a notice that it may be discontinued. Pointing Slack straight at an Apex endpoint needs a public endpoint that runs as the guest user. We chose code hosted by Slack, which calls the org through a dedicated integration user.

## Consequences

- Every channel in the community workspace is public and private channels are not available. Content is posted there only once it is public.
- Slack does not tell an app which Trailblazer ID a person has. The first time someone acts from Slack, they follow a link to the site and sign in once, which ties their Slack account to their member record. Voting from Slack therefore comes after ADR 0009.
- Posts follow Slack's guidance for screen readers: a plain-text summary on every message, a spoken label on every button, and no emoji as controls. We test buttons and forms with NVDA and JAWS when we build them.
- Emoji reactions are not votes. See ADR 0003.
