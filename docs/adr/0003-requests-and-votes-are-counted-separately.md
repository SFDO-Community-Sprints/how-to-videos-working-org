---
status: accepted
---

# Requests and votes are counted separately

Content carries two numbers. Request Count is the number of different email addresses among the requests that point to it. Vote Count is the number of votes that signed-in people have cast on it. Leadership sees both, and neither one decides anything. The priority queue is set by people at a convening.

The team's whiteboard counts a repeat request as "+1 vote". We keep that signal and give it its own name, because the two numbers deserve different trust. A request comes from an email address that someone typed into a public form. A vote comes from a person who signed in.

## How each is counted

**Request Count** is a DLRS roll-up from Case to `HowToContent__c` that counts distinct values of the requester's email address. One person who asks three times counts once. The DLRS documentation lists Count Distinct as a supported operation. We have not yet run it against the Case web email field.

**Vote Count** is a native roll-up summary over `Vote__c`, which is a master-detail child of `HowToContent__c`. DLRS is used only where the platform cannot count, which is across the lookup from Case.

## Voting rules

- Upvote only. The charter asks for upvoting "similar to Reddit or the current Idea Exchange", and both of those have downvotes. We leave downvotes out because a vote answers one question: how many people want this. Adding downvotes later means one new field and one changed roll-up.
- One vote for each person on each content record, and the person can withdraw it. `Voter_Key__c` is required and unique, and holds the content ID followed by the voter's user ID. A validation rule rejects any other key. The database therefore refuses a second vote, even when two requests arrive at the same moment.
- Declined content stops taking votes.
- Emoji reactions in Slack are not votes.

## Consequences

- Only Team Leadership can see who voted. Other people see totals. Team members hold no access to `Vote__c`, and one Apex service casts and withdraws votes for the person who is signed in.
- In round 1 the voters are the org's internal users. Members of the public site vote in a later round, through the same service. See ADR 0009.
- Nothing fills the voter key automatically. Every writer must supply the right key, so a vote can be written as an upsert on the key and a double click is harmless. Apex tests proved the key and the count in the first design, where votes hung from a different parent. The tests move with the object.
