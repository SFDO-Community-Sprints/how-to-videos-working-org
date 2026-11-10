// Refuses files that would put a person's identity or the org's location into this public repository:
// email addresses outside example.com, Salesforce instance URLs, dashboard owner or running-user fields,
// and the org ID anywhere except the public request form.
// Usage: node scripts/check-public.mjs <file> [<file> ...]   (lint-staged passes the staged files)
import { existsSync, readFileSync } from "node:fs";
import { relative } from "node:path";

const FORM = "form/index.html";
const rules = [
  { name: "email address", pattern: /[A-Za-z0-9._%+-]+@(?!([A-Za-z0-9-]+\.)*example\.com\b)[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}/g },
  { name: "instance URL", pattern: /[A-Za-z0-9-]+\.(my\.salesforce\.com|lightning\.force\.com|my\.site\.com)/g },
  { name: "dashboard owner or running user", pattern: /<(owner|runningUser)\b/g },
  { name: "org ID", pattern: /\b00D[A-Za-z0-9]{12}([A-Za-z0-9]{3})?\b/g, allowIn: [FORM] }
];

let failures = 0;
for (const file of process.argv.slice(2)) {
  const path = relative(process.cwd(), file);
  // package-lock.json is skipped: npm writes it from public registry data, and a package's deprecation notice can carry
  // its maintainer's contact address. Removing one by hand lasts only until npm resolves that package again.
  if (path.endsWith("package-lock.json") || !existsSync(file)) continue;
  const lines = readFileSync(file, "utf8").split("\n");
  for (const rule of rules) {
    if (rule.allowIn?.includes(path)) continue;
    lines.forEach((line, i) => {
      if (line.match(rule.pattern)) {
        console.error(`${path}:${i + 1}: ${rule.name} must not be committed to this public repository`);
        failures++;
      }
    });
  }
}
process.exit(failures ? 1 : 0);
