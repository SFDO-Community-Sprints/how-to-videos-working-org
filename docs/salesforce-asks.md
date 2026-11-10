# What we need from Salesforce and the Commons team

The Nonprofit How-To Series is building its system of record on Salesforce. People ask for how-to content through a public form. The team triages each request, votes on ideas, and moves each piece of content from script to publication. The design is in [`plan.md`](plan.md).

This list is in the order that blocks us. Where a number appears, it is our estimate for the first year.

## For round 1

1. **Full Salesforce licenses in the working org, about 100.** The org has one, and it is in use. Triage and voting are done by internal users, and a request is a Case, which a Salesforce Platform license does not include. The number covers the team and the people at one sprint who want a login. It is an estimate.
2. **A longer life for the working org.** It is a Nonprofit Cloud trial that expires on 2026-12-11. We need the trial extended, or a permanent org to move to.
3. **A named owner for the org at Salesforce,** and a statement of where Salesforce wants the source kept.
4. **A sending email address that the org is authorised to use.** Requesters get an email on receipt, at triage, and at publication.
5. **A usage allowance for generative AI.** One prompt template call runs at triage, to suggest content that a new request may duplicate.
6. **GitHub Pages turned on for this repository.** This one is for the repository's admins. The public request form is one HTML page in the repository.

## What the charter leaves open

1. **Where published content is hosted, and who controls that account.** The charter asks "Who has control of this account?" about the YouTube channel. The design does not assume YouTube until the team decides.
2. **Shared storage that no single volunteer owns.** Raw materials sit in a free personal Google account. The team cannot qualify for Google for Nonprofits, because it is not a registered charity.
3. **Long-lived demo orgs for screen recording,** with Nonprofit Success Pack and with Agentforce Nonprofit, and sample data. Public trials last 30 days, so each video is recorded in a different org.
4. **A statement of where NPSP, Program Management Module, Volunteers for Salesforce, and Outbound Funds stand.** The charter ranks products with a long future above those with a published end of life.
5. **Written permission to use Salesforce product names** in content titles and on the site. The Commons Terms of Participation forbid using Salesforce names to promote work without it.
6. **A review of the team's AI-use guidelines.** The charter requires disclosure when AI is used.
7. **A documentation contact for Agentforce Nonprofit,** so that each piece of content links to the current documentation.

## For the public site, in round 2

1. **Confirmation that signed-out traffic on the site is covered.**
2. **A custom domain,** or approval to use one.

## For Slack, in rounds 3 and 5

1. **Approval to deploy the team's Slack app in the Trailblazers Slack organisation,** and a channel for it. We found no published process for community-built apps.
2. **Who moderates threads in that channel.**
3. **Whether the workspace limits how long a message can be edited.** A post that shows a live count needs to be updated.

## For members, in round 4

1. **A Trailblazer ID client registration.** The wording we propose:

   > The Nonprofit How-To Series is building a volunteer Experience Cloud site where Trailblazers vote on ideas for how-to content. We request an OpenID Connect client registration on the Trailblazer ID provider (`https://iis.digital.salesforce.com`):
   >
   > - authorization code flow
   > - scopes `openid email profile`
   > - redirect URI `https://<our-site-domain>/services/authcallback/<suffix>`
   > - confirmation that `sub` is stable and unique to each account
   >
   > We will use it only for sign-in and to hold each member to one vote on each idea. We will not store tokens. Who owns Trailblazer ID client registrations, what terms apply, and has the sign-in page had an accessibility review?

2. **Member-based Customer Community licenses and data storage,** sized for more than 10,000 members. Anyone with a Trailblazer ID can sign in.
3. **Whether Trailblazer ID can give an identifier that matches the one it gives Slack.** Without it, each person links their Slack account to their member record once, by signing in on the site.

## What we are not asking for

- **Customer Community Plus or Partner licenses.** Members never need roles or sharing rules.
- **Knowledge or Service Cloud Voice.** The design does not use them.
- **A managed package or security review.** The org is the working copy, and this repository is its backup.
