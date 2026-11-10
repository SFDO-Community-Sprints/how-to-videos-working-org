# how-to-videos-working-org

The How-To Videos team has a Salesforce org, and this repository is its backup. It also holds the design for what the team is building in that org.

The team is the Nonprofit How-To Series, a Salesforce.org Open Source Commons project that makes short how-to videos for nonprofit users and admins.

## What the org does

People ask for how-to content through a public form. Each request is a Case. The Queue Manager triages it and ties it to a content record, either an existing one or a new idea. Team members vote on ideas, Team Leadership accepts or declines them at a convening, and accepted content moves from script to publication.

Round 1 is built as a prototype in the working org for the team to click through. It is not yet in use: the org has one login. The build plan says what is built and what is not.

## Where to read

- [`docs/plan.md`](docs/plan.md) is the build plan: what round 1 contains, what comes later, and what the team still has to decide.
- [`GLOSSARY.md`](GLOSSARY.md) is the project's vocabulary. Use these words in field labels, emails, and conversation.
- [`docs/adr/`](docs/adr/) holds the decisions and the reasons for them.
- [`docs/salesforce-asks.md`](docs/salesforce-asks.md) lists what the project needs from Salesforce and the Commons team.

## How the org and this repository fit together

The org is the working copy. Volunteers build there with clicks, and the repository receives a retrieve after each working session. Code starts in the repository and is deployed to the org. See [ADR 0007](docs/adr/0007-the-org-is-the-working-copy.md).

[`manifest/package.xml`](manifest/package.xml) lists every component the project owns. After each working session, retrieve them and commit:

```sh
scripts/retrieve.sh
```

The script retrieves the manifest's components and removes the dashboard owner and running user, which name a person. A pre-commit check refuses email addresses outside `example.com`, instance URLs, and the org ID anywhere except the public form (the npm lockfile is not checked).

The three Case value sets in the manifest are shared with Nonprofit Cloud. The project owns only these values in them:

- Status: Qualified, Not Qualified
- Type: New content, Problem with existing content
- Origin: Community, Comms, Internal, Import

A deploy replaces a whole value set, so:

- Code deploys name their own paths with `--source-dir` and never use the manifest.
- A deploy that includes `standardValueSets` goes in this order: retrieve the three sets, add our values, validate, deploy, then confirm that every earlier value is still there.

To deploy code, run `scripts/deploy.sh <path> ...`. It validates and then quick-deploys with the project's Apex tests. The org cannot run all local tests: four classes that came with it have no tests, which holds org-wide coverage below the 75% Salesforce requires.

Round 1 also depends on org settings that are not components and so are not in the manifest. They were set in Setup:

- Web-to-Case is on.
- Support Settings name a Default Case Owner and an Automated Case User. Salesforce requires both before a Case assignment rule can exist.
- Field history is on for Case Status and Owner. Nonprofit Cloud had already turned it on, so the project's files do not set it.
- The Declarative Lookup Rollup Summaries package is installed and unused. An earlier design counted requests with it.

The public request form is [`form/index.html`](form/index.html), a plain Web-to-Case page. It is the only file that holds the org ID. It is not published yet; a repository admin turns on GitHub Pages.

To set up the prototype's sample data, assign the permission set groups and seed. Both scripts are safe to run again:

```sh
sf apex run --file scripts/apex/assign-how-to-groups.apex --target-org howto-npc
sf apex run --file scripts/apex/seed-sample-data.apex --target-org howto-npc
```

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
