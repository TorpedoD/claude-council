#!/usr/bin/env node
// LLM Council installer for Claude Code.
// Zero-dep Node CLI. Copies skill from this package into ~/.claude/.
//
// Usage:
//   npx github:TorpedoD/claude-council add           # install skill
//   npx github:TorpedoD/claude-council list           # list available + installed
//   npx github:TorpedoD/claude-council remove         # remove skill
//
// Flags:
//   --force / -f   overwrite existing without backup
//   --dry-run      print actions without writing
//   --no-backup    skip .bak backup when overwriting
//   --help / -h    show help

import { readdirSync, existsSync, mkdirSync, cpSync, rmSync, renameSync } from "node:fs";
import { join, dirname, resolve } from "node:path";
import { homedir } from "node:os";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const PKG_ROOT = resolve(__dirname, "..");
const SRC_SKILLS = join(PKG_ROOT, "skills");

const CLAUDE_HOME = process.env.CLAUDE_HOME || join(homedir(), ".claude");
const DST_SKILLS = join(CLAUDE_HOME, "skills");

const useColor = !process.env.NO_COLOR && process.stdout.isTTY;
const c = (code, s) => (useColor ? `\x1b[${code}m${s}\x1b[0m` : s);
const bold = (s) => c("1", s);
const dim = (s) => c("2", s);
const green = (s) => c("32", s);
const yellow = (s) => c("33", s);
const red = (s) => c("31", s);
const cyan = (s) => c("36", s);

const argv = process.argv.slice(2);
const flags = new Set();
const positional = [];
for (const a of argv) {
  if (a.startsWith("--") || /^-[a-zA-Z]$/.test(a)) flags.add(a);
  else positional.push(a);
}
const has = (...names) => names.some((n) => flags.has(n));
const DRY = has("--dry-run");
const FORCE = has("--force", "-f");
const NO_BACKUP = has("--no-backup");
const HELP = has("--help", "-h");

const subcommand = positional[0];
const target = positional[1];

function listSkills() {
  if (!existsSync(SRC_SKILLS)) return [];
  return readdirSync(SRC_SKILLS, { withFileTypes: true })
    .filter((d) => d.isDirectory())
    .map((d) => d.name);
}

function isInstalledSkill(name) {
  return existsSync(join(DST_SKILLS, name));
}

function ensureDir(p) {
  if (DRY) return;
  mkdirSync(p, { recursive: true });
}

function backup(path) {
  if (DRY) return;
  const bak = `${path}.bak`;
  if (existsSync(bak)) rmSync(bak, { recursive: true, force: true });
  renameSync(path, bak);
}

function installSkill(name) {
  const src = join(SRC_SKILLS, name);
  if (!existsSync(src)) {
    console.log(red(`  ✗ skill not found: ${name}`));
    return false;
  }
  const dst = join(DST_SKILLS, name);
  if (existsSync(dst)) {
    if (FORCE && NO_BACKUP) {
      console.log(yellow(`  ⟳ ${name} exists — overwriting`));
      if (!DRY) rmSync(dst, { recursive: true, force: true });
    } else {
      console.log(yellow(`  ⟳ ${name} exists — backing up to ${name}.bak`));
      backup(dst);
    }
  }
  if (!DRY) cpSync(src, dst, { recursive: true });
  console.log(green(`  ✓ skill: ${name}`));
  return true;
}

function removeSkill(name) {
  const dst = join(DST_SKILLS, name);
  if (!existsSync(dst)) {
    console.log(dim(`  - skill not installed: ${name}`));
    return false;
  }
  if (!DRY) rmSync(dst, { recursive: true, force: true });
  console.log(green(`  ✓ removed skill: ${name}`));
  return true;
}

function cmdAdd() {
  const skills = listSkills();

  console.log(bold("→ LLM Council installer"));
  console.log(dim(`  source: ${PKG_ROOT}`));
  console.log(dim(`  target: ${CLAUDE_HOME}`));
  if (DRY) console.log(yellow("  (dry run — no files will be written)"));
  console.log();

  ensureDir(DST_SKILLS);

  if (target) {
    const asSkill = skills.includes(target);
    if (!asSkill) {
      console.log(red(`Unknown skill: ${target}`));
      console.log(dim("Run with `list` to see what's available."));
      process.exit(1);
    }
    installSkill(target);
  } else {
    console.log(bold("Skills"));
    for (const s of skills) installSkill(s);
  }

  console.log();
  console.log(green("✓ Done."));
  console.log();
  console.log(bold("Next steps:"));
  console.log(`  1. Install jq (required for journal):`);
  console.log(dim(`       brew install jq`));
  console.log(`  2. Open Claude Code and run: ${cyan("/claude-council \"your decision\"")}`);
}

function cmdList() {
  const skills = listSkills();
  console.log(bold("Skills") + dim(`  (source → ~/.claude/skills)`));
  for (const s of skills) {
    const status = isInstalledSkill(s) ? green("installed") : dim("not installed");
    console.log(`  ${s}  ${status}`);
  }
}

function cmdRemove() {
  if (!target) {
    console.log(red("Usage: remove <name>"));
    process.exit(1);
  }
  const skills = listSkills();
  const asSkill = skills.includes(target);
  if (!asSkill) {
    console.log(red(`Unknown skill: ${target}`));
    process.exit(1);
  }
  removeSkill(target);
}

function cmdHelp() {
  console.log(`${bold("claude-council")} — LLM Council slash command for Claude Code
${dim("repo: https://github.com/TorpedoD/claude-council")}

${bold("Usage")}
  npx github:TorpedoD/claude-council ${cyan("add")}              install skill
  npx github:TorpedoD/claude-council ${cyan("add <name>")}       install one
  npx github:TorpedoD/claude-council ${cyan("list")}             show available / installed
  npx github:TorpedoD/claude-council ${cyan("remove <name>")}    uninstall one

${bold("Flags")}
  --force, -f     overwrite existing (still backs up to .bak unless --no-backup)
  --no-backup     skip .bak backup when overwriting
  --dry-run       print what would happen without touching the filesystem
  --help, -h      show this message

${bold("Environment")}
  CLAUDE_HOME     override target directory (default: ~/.claude)
  NO_COLOR        disable ANSI colors

${bold("Examples")}
  npx github:TorpedoD/claude-council add
  npx github:TorpedoD/claude-council add claude-council
  npx github:TorpedoD/claude-council list
  CLAUDE_HOME=/tmp/claude-test npx github:TorpedoD/claude-council add --dry-run
`);
}

if (HELP || !subcommand) {
  cmdHelp();
  process.exit(0);
}

try {
  switch (subcommand) {
    case "add":
    case "install":
      cmdAdd();
      break;
    case "list":
    case "ls":
      cmdList();
      break;
    case "remove":
    case "uninstall":
    case "rm":
      cmdRemove();
      break;
    case "help":
      cmdHelp();
      break;
    default:
      console.log(red(`Unknown command: ${subcommand}`));
      console.log();
      cmdHelp();
      process.exit(1);
  }
} catch (err) {
  console.error(red("✗ Error:"), err.message);
  if (process.env.DEBUG) console.error(err.stack);
  process.exit(1);
}
