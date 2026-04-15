#!/usr/bin/env node
/**
 * Merge package-lock.json `packages[""].dependencies` into package.json `dependencies`
 * so direct deps match the lockfile (e.g. github: specs -> tarball URLs after lock rewrite).
 */
import { readFileSync, writeFileSync } from "node:fs";

const lock = JSON.parse(readFileSync("package-lock.json", "utf8"));
const pkg = JSON.parse(readFileSync("package.json", "utf8"));
const rootDeps = lock.packages?.[""]?.dependencies;
if (!rootDeps || typeof rootDeps !== "object") {
	console.error(
		"sync-deps-from-lock: missing packages[''].dependencies in package-lock.json",
	);
	process.exit(1);
}
pkg.dependencies = { ...pkg.dependencies, ...rootDeps };
writeFileSync("package.json", `${JSON.stringify(pkg, null, 2)}\n`);
