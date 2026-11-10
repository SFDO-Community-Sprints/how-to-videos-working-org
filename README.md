# how-to-videos-working-org

The How-To Videos team has a Salesforce org, and this repository is its backup. It also holds the design for what the team is building in that org.

The team is the Nonprofit How-To Series, a Salesforce.org Open Source Commons project that makes short how-to videos for nonprofit users and admins.

## What the org does

People ask for how-to content through a public form. Each request is a Case. The Queue Manager triages it and ties it to a content record, either an existing one or a new idea. Team members vote on ideas, Team Leadership accepts or declines them at a convening, and accepted content moves from script to publication.

Nothing is built yet. Round 1 is described in the build plan.

## Where to read

- [`docs/plan.md`](docs/plan.md) is the build plan: what round 1 contains, what comes later, and what the team still has to decide.
- [`GLOSSARY.md`](GLOSSARY.md) is the project's vocabulary. Use these words in field labels, emails, and conversation.
- [`docs/adr/`](docs/adr/) holds the decisions and the reasons for them.
- [`docs/salesforce-asks.md`](docs/salesforce-asks.md) lists what the project needs from Salesforce and the Commons team.

## How the org and this repository fit together

The org is the working copy. Volunteers build there with clicks, and the repository receives a retrieve after each working session. Code starts in the repository and is deployed to the org. See [ADR 0007](docs/adr/0007-the-org-is-the-working-copy.md).

The manifest that lists the project's components is added with the first component. Until then there is nothing to retrieve.

The working org is a trial that expires on 2026-12-11 unless Salesforce extends it.

## Tooling

The repository is a Salesforce DX project with Prettier, ESLint, and Jest for Lightning web components.

To install the tools, run:

```sh
npm install
```

To format the source, run:

```sh
npm run prettier
```

## License

BSD 3-Clause. See [`LICENSE`](LICENSE).
