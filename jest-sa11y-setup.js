// Adds the toBeAccessible() matcher from Sa11y (axe-core) to every Jest test.
import { registerSa11yMatcher } from "@sa11y/jest";

registerSa11yMatcher();
