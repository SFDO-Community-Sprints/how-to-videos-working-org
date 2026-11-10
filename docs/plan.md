# Build plan

What exists, what round 1 builds, what comes after, and what the team still has to decide. The reasons behind the design are in [`docs/adr/`](adr/). The words are in [`GLOSSARY.md`](../GLOSSARY.md). The requests to Salesforce are in [`salesforce-asks.md`](salesforce-asks.md).

## Where things stand

Round 1 is built in the working org as a prototype for the team to click through. The repository holds its components, the public request form, and scripts that assign access and create made-up sample data. Nobody on the team can use it yet, because the org has one login.

Where the prototype differs from this plan, or has not been proved:

- **The public form has not created a request.** Web-to-Case is on and accepts the form's posts, but the org created no case, and no error reached the org's logs. The cause is not known. Salesforce emails Web-to-Case failures to the Default Case Owner. Every step after the form was proved with requests created through the API.
- **Requester emails come from flows, not email templates or an auto-response rule.** The six messages are text in the flows, and each email is logged on its request. Salesforce sends an email template only to a contact, lead, or person account, and a request has none. An auto-response rule needs a sending address in its definition, which would put an email address in this public repository.
- **The New form for a request uses the profile's Case layout.** Assigning a layout to the Video Request record type is a profile change. The request record page does not depend on the layout.
- **Team members submit ideas from the voting board.** Submit an idea files an Internal request in the triage queue.
- **The org needs two Support Settings.** Salesforce requires a Default Case Owner and an Automated Case User before a Case assignment rule can exist.
- **A vote belongs to an email address.** A qualified request without an email address casts no vote. A request typed with a team member's address turns that member's board vote into a request vote, which they cannot withdraw while the request stands. When a user's email address changes, their earlier board votes stay under the old address, so they can count twice until they withdraw one. Two users who share an address share one vote, and only the one who cast it can withdraw it. ADR 0009 replaces this for members in round 4.
- **A user whose email address is longer than 80 characters cannot vote on the board.** The vote's email field holds 80 characters, and Salesforce will not widen it while votes exist, including deleted votes it has not yet purged. No user in the org has an address that long. If one appears before round 4, widen the field and the voter key together.
- **Salesforce's integration users can read every vote.** The Slack and Analytics integration users hold View All Data, which covers every object. Nobody signs in as them. Check what the Slack integration can show before round 3.
- **Not proved: voting as someone with no access to votes.** The voting board's service gives team members no direct access to votes and works in system mode for them. Its tests run as the org's only user, a System Administrator, so they cannot show the difference. The configuration is checked instead: apart from View All Data holders, only Team Leadership can read votes.

The working org is a Nonprofit Cloud trial on Enterprise Edition. Three facts about it shape the plan:

- It has one full Salesforce license, and that license is in use. Nobody else can be given an internal login until Salesforce adds seats. Round 1 can be built under one login. It cannot be used by the team.
- The trial expires on 2026-12-11 unless Salesforce extends it.
- Case already has two record types and six statuses that belong to Nonprofit Cloud. Person accounts are on. Generative AI is on. Web-to-Case was off until round 1 turned it on.

An earlier design was prototyped in a Developer Edition org in November 2026 and then set aside. Its findings about how Case, votes, and the standard Ideas feature behave are recorded in the ADRs.

## How it works

1. A person asks for content through a public form. The form creates a request, which is a Case.
2. The request lands in the triage queue, and the requester gets an email that says what happens next.
3. The Queue Manager triages the request. A request that is out of scope is closed as Not Qualified, with a reason that goes to the requester.
4. For a request that is in scope, the Queue Manager checks whether content already exists. A prompt template suggests likely matches.
5. If content exists, the request is linked to it. The requester is told where the content is, or that it is in progress.
6. If no content exists, the Queue Manager creates a content record from the request. Its status is Submitted, which makes it an idea.
7. Team members vote on ideas. Each qualified request also counts as one vote for its requester.
8. At a convening, Team Leadership accepts or declines ideas. Accepted content joins the priority queue.
9. Content moves through Drafting, Proofing, Production, Editing, and Final Review to Published. Everyone who asked for it gets an email when it is published.

## Round 1

Round 1 is everything inside the org. It has no public site. It follows the team's whiteboard lists from 2026-11-09.

### Request

A request is a Case with the record type Video Request.

- **Subject.** The title. A validation rule requires it.
- **Description.** What the person wants.
- **Type.** The kind of request. Starting values are New content and Problem with existing content. The team sets the final list.
- **Case Origin.** Community for the public form, Comms for a request that arrived by Slack or email and was entered by a team member, Internal for a team member's own request, and Import.
- **Product.** A picklist that content shares.
- **Feature.** Free text.
- **Web Name and Web Email.** The requester.
- **Content.** A lookup to the content record.
- **Not Qualified Reason.** Required when a request is Not Qualified. It is sent to the requester.
- **Status.** New, Qualified, or Not Qualified. Qualified and Not Qualified are closed statuses.
- **Owner.** The triage queue.

A request is Qualified if and only if it points to content.

### Content

Content is the custom object `HowToContent__c`.

- **Title.** The record name, up to 80 characters.
- **Status.** Submitted, Accepted, Drafting, Proofing, Production, Editing, Final Review, Published, Retired, or Declined.
- **Type.** The format. The only value for now is Video.
- **Product and Feature.** Copied from the first request.
- **Summary.** Plain text.
- **Champion Name and Champion Email.** Copied from the first request. Team Leadership can change them. Both are required before Accepted.
- **Team Response.** Required to decline.
- **Queue Position.** A number. Position 1 is produced first. Only the Queue Manager can change it.
- **Drive Folder.** Required in Production, Editing, and Final Review.
- **Scratch Track, Screen Recording, and Production Track Collected.** Three checkboxes. All are required in Editing and Final Review.
- **Published Date.** Required when Published or Retired.
- **Vote Count.** The number of different people who asked for the content or voted for it. A roll-up summary of votes.
- **Owner.** The holder. A Salesforce queue owns content that nobody holds yet.

Content moves forward one status at a time from Drafting onward, and back any distance. Content that requests point to cannot be deleted.

Where published content is hosted is not decided. Round 1 has no link, player, or YouTube field.

### Vote

A vote is the custom object `Vote__c`, a master-detail child of content. It holds the voter's email address, a lookup to the voter's user when they voted on the voting board, its source (a request or the voting board), and the required, unique `Voter_Key__c`. See ADR 0003.

### Automation

- An assignment rule sends each Video Request to the triage queue.
- An auto-response rule emails the requester on receipt.
- Two flows run from the request page. One creates content from the request. The other links the request to existing content. Both show the duplicate check's suggestions.
- A flow emails the requester when triage closes the request. There are four templates: logged as a new idea, here is the existing content, already in progress, and not qualified with the reason.
- A flow emails every requester of a content record when it is published.
- A flow casts a vote for the requester when triage qualifies a request. It moves or removes that vote if triage later links the request elsewhere or unlinks it.

### Screens

- Two apps over the same tabs: one console app and one with standard navigation.
- Page layouts and record pages for requests and content.
- List views: Triage Queue, All Requests, Ideas, Priority Queue, and Published.
- Reports and one dashboard.
- A voting board. It is one Lightning web component on the app's home page, and the only custom component in round 1. It lists the ideas, each with its total and a Vote or Withdraw button. Your own vote updates the total at once and is announced to screen readers. Other people's votes appear when you refresh, so the list does not change while you read it.

### Access

- Three permission set groups: How-To Team Member, How-To Team Leadership, and How-To Queue Manager. The Queue Manager's group includes the standard permission to run prompt templates.
- Only Team Leadership can see who voted.
- Field history on request Status and Owner, and on content Status, Owner, and Queue Position.
- Only the holder or an administrator can change the holder of content that someone holds. Any team member can take content from the queue.

### The public form

One HTML page in this repository, published with GitHub Pages. See ADR 0004.

### What already exists, to bring in

- The published videos, as content with the status Published. The whiteboard calls this video migration.
- The answers to the Google Form idea survey from January 2026 and the open GitHub issues, as requests with the origin Import. Triage of these is the first real trial of the duplicate check.

The people behind imported requests did not agree to have their names shown. Content that comes from an imported request has no champion name until that person agrees or Team Leadership names another champion.

## What the whiteboard's build list asked for, and where it is

1. Data model, objects, and record types. See Request, Content, and Vote above.
2. Fields, types, and picklist values. The same sections.
3. Page layouts, record pages, and list views. See Screens.
4. Service console. One of the two apps.
5. Web-to-Case form and auto-responder. See The public form and Automation.
6. Queue, routing rules, and case assignment rules. One triage queue and one assignment rule.
7. Field history tracking and audit trail. See Access.
8. Email templates. Six: one on receipt, four at triage, and one at publication.
9. Permission set and permission set group. See Access.
10. Videos to YouTube. Not built. The team has not decided where videos are hosted.
11. Reports and dashboards. See Screens.

## Where the design differs from the whiteboards

The team should confirm each of these.

- **The requester gets an email where the whiteboard says to post on the case with Chatter or a comment.** A requester has no login to read a post.
- **"In progress, follow here" has no link in round 1.** There is no public page to follow until round 2. The email says the request was counted.
- **Triage decides scope, not acceptance.** The Queue Manager qualifies a request. Accepting an idea stays a unanimous leadership decision at a convening, as the charter says.

## Later rounds

2. **The public site, read-only.** The priority queue and published content for visitors, on an LWR site. An NVDA and JAWS pass on every page. See ADR 0008.
3. **Slack notices.** One post for each piece of public content, with status changes in its thread. See ADR 0010.
4. **Members.** Sign-in with Trailblazer ID, voting on the site, and a public voting status. See ADR 0009.
5. **Requests and votes from Slack.**
6. **After publication.** Helpful or not helpful on each piece of content, problem reports as requests with their own type, and a review date that puts ageing content back in front of the team.

## What the charter asks for, and where it is

- **Every idea has an identified champion (4.2.3).** Champion Name and Champion Email on content, required before Accepted.
- **Ideas can be upvoted (4.2.3).** `Vote__c`, one for each person on each idea.
- **Acceptance is a unanimous leadership decision (4.2.3).** Only Team Leadership can set content to Accepted. The org does not record who agreed.
- **Stages advance in order and can regress (4.2.3).** A validation rule on content Status.
- **Production collects three recordings (4.2.3).** Three checkboxes, all required before Editing.
- **One Drive folder for each video (4.3.3).** Drive Folder, required from Production on.
- **The org records who holds each video (4.3.2).** The record owner, with history. See ADR 0006.
- **Tasks and task assignments (4.3.2).** Standard Tasks on content.
- **One priority queue with no tiers, changed only at a convening (3, 4.1.1).** Queue Position, with history. Nothing yet records which convening made a change.
- **Roadmap alignment ranks first among the prioritization principles (4.1.2).** Product on requests and content.

Not yet in the design:

- **AI disclosure (4.3.5).** Content should record what AI was used for. This waits for the team's AI guidelines.
- **Who may advance each status.** The charter gives Proofing to the proofer, the edit to the Production Manager, and the final review to the Queue Manager. In round 1 any team member can advance a status.
- **What happens when content is outdated (4.3.4).** The Retired status exists. The procedure does not.
- **Ideal content (2.2).** The five criteria belong on the public form as guidance, and as reasons a request is not qualified.
- **Captions and transcripts.** We suggest that content cannot be published without reviewed captions. This is our suggestion, not the charter's.

## Decisions for the team

Each has a default that the build assumes until a convening decides.

1. **Published and Retired as statuses.** The charter ends at Final Review. Default: add both.
2. **No downvotes.** Default: upvote only.
3. **Whether voting stays open after an idea is accepted.** Default: yes, until the content is published.
4. **Who may advance each status.** Default: any team member.
5. **The Product list, and the Type lists for requests and for content.**
6. **Where published content is hosted,** and what a published record must carry.
7. **The three differences from the whiteboards,** listed above.
8. **Whether the Queue Manager can take content from a holder.** Default: no. The holder hands content over or returns it to the queue, and an administrator moves content whose holder cannot. If the team says yes, round 1 gains one reassign action that runs in system context.
