---
status: accepted
---

# A qualified request counts as a vote

Content carries one number, Vote Count: the number of different people who have asked for it or voted for it. When triage qualifies a request, the request casts a vote for its requester. A team member who votes casts one too. Each person counts once, however many times they ask or vote. Leadership sees the count, and the count decides nothing on its own. The priority queue is set by people at a convening.

This is what the team's whiteboard means when it counts a repeat request as "+1 vote".

## Considered options

**Count requests and votes separately.** A requester's email address is typed into a public form, and a voter has signed in, so the two could be trusted differently. We rejected it because two numbers leave leadership to weigh one against the other with no rule for doing so, and because every request already passes a person at triage before it counts. It would also need DLRS to count distinct email addresses across the lookup from Case, which we have not tested.

## How it is counted

Every vote is a `Vote__c` record, a master-detail child of `HowToContent__c`. Vote Count is a native roll-up summary over it.

- One vote for each person on each content record. `Voter_Key__c` is required and unique, and holds the content ID followed by the voter's email address in lower case. A validation rule rejects any other key. The database therefore refuses a second vote, even when two arrive at the same moment, and a person who both asks and votes counts once.
- A flow casts the vote when triage qualifies a request. If the requester already has a vote on that content, nothing changes.
- If triage later links the request to different content, or unlinks it, the flow moves or removes the vote that the request cast. The vote stays where another request from the same address still points to the old content.
- Each vote records its source: a request or the voting board.

## Voting rules

- Upvote only. The charter asks for upvoting "similar to Reddit or the current Idea Exchange", and both of those have downvotes. We leave downvotes out because a vote answers one question: how many people want this. Adding downvotes later means one new field and one changed roll-up.
- A person who signed in can withdraw their vote. A requester has no login, so a vote cast by a request stays while the request points to the content.
- Declined content stops taking votes.
- Emoji reactions in Slack are not votes.

## Consequences

- Only Team Leadership can see who voted. Other people see totals. Team members hold no access to `Vote__c`, and one Apex service casts and withdraws votes for the person who is signed in.
- The total alone does not show how much of it came from requests. A report on each vote's source shows the split.
- The email address on a request is not verified, so someone who sends requests from several addresses can raise the count. Each of those requests must get past triage first. See ADR 0004.
- In round 1 the voters are the org's internal users, who are the team itself. Until members of the public can vote, the count mixes what the public asked for with what the team supports. Members vote in a later round, through the same service. See ADR 0009.
- Nothing fills the voter key automatically. Both writers, the Apex service and the triage flow, must supply the right key, so a vote can be written as an upsert on the key and a double click is harmless. Apex tests proved the key and the count in the first design, where votes hung from a different parent and the key held a user ID. The tests move with the object.
