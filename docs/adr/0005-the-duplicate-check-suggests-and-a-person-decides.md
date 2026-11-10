---
status: accepted
---

# The duplicate check suggests, and the person at triage decides

At triage, a prompt template compares the request with the titles of all existing content and returns a short list of likely matches, each with a reason. The Queue Manager then links the request to one of them or creates new content. The check never links, declines, or closes anything.

The check has to catch rephrasing. "How do I set up recurring donations" must match "Walkthrough of Enhanced Recurring Donations configuration". Keyword search does not do that, and standard duplicate rules do not support Case.

## Considered options

**An Agentforce agent.** An agent earns its place when there is a conversation, or a choice between several actions. This check has a fixed input, one question, and a list back. Salesforce also documents that agent actions called from Flow or Apex are not supported for Experience Cloud site users, which would block a later round. A prompt template is part of the same platform, lives in the repository, and can be reworded without code.

**A search index in Data Cloud.** This is Salesforce's documented route for finding text by meaning. It needs a working Data Cloud tenant, a data stream, an index, and a retriever. At a few hundred content records, every title fits in one prompt. The index becomes the right design somewhere above 1,000 records, and it can replace the list of titles without changing what the Queue Manager sees.

**A check on the public form.** The first design showed matches to the person who submitted. A Web-to-Case form cannot hold that exchange. See ADR 0004.

## Consequences

- The check runs inside the triage flow, as the Queue Manager. That person needs the standard permission to run prompt templates.
- Only the title and description go to the model. The requester's name and email address are never sent.
- If the model call fails, the Queue Manager searches by hand.
- Nobody has yet called a model for this. Match quality and speed are unproven. The import of existing ideas is the first real trial.
- Apex tests cannot fake a prompt template call. Proof that the check finds real rephrasing comes from that trial, not from tests.
