#!/usr/bin/env node
import fs from "node:fs/promises";
import path from "node:path";
import { createHash } from "node:crypto";
import { execFile } from "node:child_process";
import { promisify } from "node:util";

const exec = promisify(execFile);
const args = process.argv.slice(2);
const apply = args.includes("--apply");
if (args.some((arg) => !["--dry-run", "--apply"].includes(arg)) || (apply && args.includes("--dry-run"))) {
  console.error("usage: igir-audit [--dry-run|--apply]");
  process.exit(2);
}

const QBT_API = process.env.QBT_API || "http://qbittorrent.default.svc.cluster.local/api/v2";
const QBT_TORRENTS_PATH = process.env.QBT_TORRENTS_PATH || "torrents/info?category=roms";
const QBT_FILES_PATH = process.env.QBT_FILES_PATH || "torrents/files?hash={hash}";
const DEST_ROOT = process.env.IGIR_DEST_ROOT || "/media/games/roms";
const STAGE_ROOT = process.env.IGIR_STAGE_ROOT || "/media/games/.igir-staging";
const PROMOTION_ROOT = process.env.IGIR_PROMOTION_ROOT || "/media/games/.igir-promotion";
const REPORT_FILE = process.env.IGIR_REPORT_FILE || "/tmp/igir-report.csv";
const LOCK = "/tmp/igir-audit.lock";
const IGIR_BINARY = "/tools/igir";
const ROM_ROOTS = [
  "/media/downloads/torrents/complete/roms/Minerva_Myrient",
  "/media/downloads/torrents/incomplete/roms/Minerva_Myrient",
];
const DAT_URLS = (process.env.IGIR_DAT_URLS || "")
  .split(",")
  .map((url) => url.trim())
  .filter(Boolean);
const PLATFORM_NAMES = [
  "Nintendo - Game Boy Advance",
  "Nintendo - Game Boy",
  "Nintendo - Game Boy Color",
  "Nintendo - Nintendo 3DS",
  "Nintendo - Nintendo DS",
  "Nintendo - Nintendo 64",
  "Nintendo - Nintendo 64 (BigEndian)",
  "Nintendo - Nintendo Entertainment System",
  "Nintendo - Nintendo Entertainment System (Headerless)",
  "Nintendo - Super Nintendo Entertainment System",
];

async function getJson(endpoint, attempts = 3) {
  let lastError;
  for (let attempt = 1; attempt <= attempts; attempt += 1) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 15000);
    try {
      const response = await fetch(`${QBT_API}/${endpoint}`, { signal: controller.signal });
      if (!response.ok) throw new Error(`qBittorrent ${response.status}: ${endpoint}`);
      return await response.json();
    } catch (error) {
      lastError = error;
      if (attempt < attempts) await new Promise((resolve) => setTimeout(resolve, attempt * 1000));
    } finally {
      clearTimeout(timer);
    }
  }
  throw lastError;
}

function containedPath(root, candidate) {
  const relative = path.relative(path.resolve(root), path.resolve(candidate));
  return relative && !relative.startsWith(`..${path.sep}`) && !path.isAbsolute(relative);
}

function platformRelative(file, root) {
  const relative = path.relative(path.resolve(root), path.resolve(file));
  if (!relative || relative.startsWith(`..${path.sep}`) || path.isAbsolute(relative)) return null;
  const parts = relative.split(path.sep);
  const index = parts.findIndex((part) =>
    PLATFORM_NAMES.some((name) => part === name || part.startsWith(`${name} [`)),
  );
  return index < 0 ? null : parts.slice(index).join(path.sep);
}

async function selectedFiles() {
  const torrents = await getJson(QBT_TORRENTS_PATH);
  if (!Array.isArray(torrents)) throw new Error("qBittorrent returned an invalid torrent list");
  const selected = [];
  for (const torrent of torrents) {
    let files;
    try {
      files = await getJson(QBT_FILES_PATH.replace("{hash}", encodeURIComponent(torrent.hash)));
    } catch (error) {
      console.log(`torrent-failed: ${torrent.hash}: ${error.message}`);
      continue;
    }
    if (!Array.isArray(files)) throw new Error(`qBittorrent returned an invalid file list for ${torrent.hash}`);
    for (const file of files) {
      if (file.priority <= 0 || file.progress < 1 || !file.name || path.isAbsolute(file.name)) continue;
      const candidate = path.resolve(torrent.content_path, file.name);
      for (const root of ROM_ROOTS) {
        if (!containedPath(root, candidate)) continue;
        try {
          await validateNoSymlinks(root, candidate);
        } catch {
          continue;
        }
        let stat;
        try {
          stat = await fs.lstat(candidate);
        } catch {
          continue;
        }
        if (!stat.isFile() || stat.isSymbolicLink()) continue;
        const relative = platformRelative(candidate, root);
        if (relative) {
          selected.push({ source: candidate, relative });
          break;
        }
      }
    }
  }
  return selected;
}

async function stageFiles(files, stage) {
  await fs.mkdir(stage, { recursive: true });
  const destinations = new Set();
  let linked = 0;
  let failed = 0;
  let skipped = 0;
  for (const file of files) {
    if (file.source.includes(`${path.sep}.unwanted${path.sep}`)) {
      skipped += 1;
      continue;
    }
    const destination = path.resolve(stage, file.relative);
    if (!containedPath(stage, destination) || destinations.has(destination)) {
      failed += 1;
      console.log(`stage-rejected: ${file.source}`);
      continue;
    }
    destinations.add(destination);
    try {
      await fs.mkdir(path.dirname(destination), { recursive: true });
      await fs.link(file.source, destination);
      linked += 1;
    } catch (error) {
      failed += 1;
      console.log(`stage-failed: ${file.source}: ${error.message}`);
    }
  }
  return { linked, failed, skipped };
}

async function validateNoSymlinks(root, candidate) {
  const rootPath = path.resolve(root);
  const candidatePath = path.resolve(candidate);
  const rootStat = await fs.lstat(rootPath);
  if (rootStat.isSymbolicLink()) throw new Error(`symlink root: ${root}`);
  if (candidatePath !== rootPath && !containedPath(rootPath, candidatePath)) {
    throw new Error(`path escaped root: ${candidate}`);
  }
  const relative = path.relative(rootPath, candidatePath);
  let current = rootPath;
  for (const component of relative ? relative.split(path.sep) : []) {
    current = path.join(current, component);
    try {
      const stat = await fs.lstat(current);
      if (stat.isSymbolicLink()) throw new Error(`symlink path component: ${current}`);
    } catch (error) {
      if (error.code === "ENOENT") break;
      throw error;
    }
  }
}

async function filesUnder(root) {
  const results = [];
  async function visit(directory) {
    for (const entry of await fs.readdir(directory, { withFileTypes: true })) {
      const item = path.join(directory, entry.name);
      if (entry.isDirectory()) await visit(item);
      else results.push(item);
    }
  }
  await visit(root);
  return results;
}

async function runIgir(command, input, output) {
  const commandArgs = [command, "--input", input];
  if (command === "report") commandArgs.push("--report-output", output);
  else commandArgs.push("--output", output);
  for (const dat of DAT_URLS) commandArgs.push("--dat", dat);
  commandArgs.push("--input-checksum-quick", "false", "--input-checksum-min", "CRC32", "--input-checksum-max", "SHA1");
  return exec(IGIR_BINARY, commandArgs, { timeout: 1800000, maxBuffer: 32 * 1024 * 1024 });
}

async function sha256(file) {
  const hash = createHash("sha256");
  hash.update(await fs.readFile(file));
  return hash.digest("hex");
}

async function promotionFile(source, promotion) {
  const stat = await fs.lstat(source);
  if (stat.isSymbolicLink()) {
    const target = await fs.realpath(source);
    await validateNoSymlinks(promotion, target);
    if (!containedPath(promotion, target)) throw new Error(`promotion link escaped staging: ${source}`);
    return { path: target, stat: await fs.stat(target) };
  }
  if (!stat.isFile()) throw new Error(`invalid promotion file: ${source}`);
  return { path: source, stat };
}

async function promote(promotion) {
  let linked = 0;
  let existing = 0;
  await validateNoSymlinks(DEST_ROOT, DEST_ROOT);
  for (const source of await filesUnder(promotion)) {
    const relative = path.relative(promotion, source);
    const destination = path.resolve(DEST_ROOT, relative);
    if (!containedPath(DEST_ROOT, destination)) throw new Error(`promotion escaped destination: ${relative}`);
    await validateNoSymlinks(DEST_ROOT, path.dirname(destination));
    const promoted = await promotionFile(source, promotion);
    await fs.mkdir(path.dirname(destination), { recursive: true });
    try {
      await fs.link(promoted.path, destination);
      linked += 1;
    } catch (error) {
      if (error.code === "EEXIST") {
        const existingFile = await fs.lstat(destination);
        if (!existingFile.isFile() || existingFile.isSymbolicLink()) throw new Error(`unsafe existing destination: ${relative}`);
        if (existingFile.size !== promoted.stat.size || await sha256(destination) !== await sha256(promoted.path)) {
          throw new Error(`existing destination differs: ${relative}`);
        }
        existing += 1;
        continue;
      }
      throw error;
    }
  }
  return { linked, existing };
}

async function main() {
  if (DAT_URLS.length === 0) throw new Error("IGIR_DAT_URLS must contain at least one DAT URL");
  try {
    await fs.mkdir(LOCK);
  } catch (error) {
    if (error.code === "EEXIST") throw new Error("another igir audit is active");
    throw error;
  }
  let stage;
  let promotion;
  try {
    const files = await selectedFiles();
    const run = new Date().toISOString().replaceAll(/[^0-9]/g, "").slice(0, 14);
    stage = `${STAGE_ROOT}-${run}`;
    const staged = await stageFiles(files, stage);
    console.log(JSON.stringify({ mode: apply ? "apply" : "dry-run", run, selected: files.length, staged, dats: DAT_URLS }));
    if (staged.failed > 0 || staged.linked + staged.skipped !== files.length) {
      throw new Error(`staging incomplete: ${staged.linked}/${files.length} linked, ${staged.skipped} skipped, ${staged.failed} failed`);
    }

    try {
      const { stdout, stderr } = await runIgir("report", stage, REPORT_FILE);
      process.stdout.write(stdout);
      process.stderr.write(stderr);
      const report = await fs.readFile(REPORT_FILE, "utf8");
      if (!report.includes("Status,")) throw new Error(`invalid Igir report: ${REPORT_FILE}`);
      process.stdout.write(report);
    } finally {
      await fs.rm(REPORT_FILE, { force: true });
    }

    if (apply) {
      promotion = `${PROMOTION_ROOT}-${run}`;
      await fs.mkdir(promotion, { recursive: true });
      const { stdout, stderr } = await runIgir("link", stage, promotion);
      process.stdout.write(stdout);
      process.stderr.write(stderr);
      const promoted = await promote(promotion);
      console.log(JSON.stringify({ promotion: promoted }));
    }
  } finally {
    if (promotion) await fs.rm(promotion, { recursive: true, force: true });
    if (stage) await fs.rm(stage, { recursive: true, force: true });
    await fs.rm(LOCK, { recursive: true, force: true });
  }
}

main().catch((error) => {
  console.error(`igir-audit failed: ${error.message}`);
  if (error.stdout) process.stdout.write(error.stdout);
  if (error.stderr) process.stderr.write(error.stderr);
  process.exitCode = 1;
});
