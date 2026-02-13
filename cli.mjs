#!/usr/bin/env node

import { readFile, access } from 'fs/promises';
import { join, basename } from 'path';
import { homedir } from 'os';

const CONFIG_PATHS = [
  '.docsrc.json',
  join(homedir(), '.docsrc.json'),
];

// ── Load config ──
async function loadConfig() {
  for (const path of CONFIG_PATHS) {
    try {
      await access(path);
      const content = await readFile(path, 'utf-8');
      return JSON.parse(content);
    } catch {}
  }
  return null;
}

// ── HTTP Request helper ──
async function request(url, options = {}) {
  const { default: fetch } = await import('node-fetch').catch(() => {
    // Fallback to native fetch in Node 18+
    return { default: globalThis.fetch };
  });

  const response = await fetch(url, options);
  const text = await response.text();

  let data;
  try {
    data = JSON.parse(text);
  } catch {
    data = { error: text };
  }

  if (!response.ok) {
    throw new Error(data.error || `HTTP ${response.status}`);
  }

  return data;
}

// ── Upload document ──
async function uploadDoc(config, filepath) {
  const filename = basename(filepath);
  const content = await readFile(filepath, 'utf-8');

  const result = await request(`${config.server}/api/docs`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${config.apiKey}`,
    },
    body: JSON.stringify({ filename, content }),
  });

  console.log(`✓ Uploaded: ${filename}`);
  return result;
}

// ── Delete document ──
async function deleteDoc(config, filename) {
  const result = await request(`${config.server}/api/docs/${encodeURIComponent(filename)}`, {
    method: 'DELETE',
    headers: {
      'Authorization': `Bearer ${config.apiKey}`,
    },
  });

  console.log(`✓ Deleted: ${filename}`);
  return result;
}

// ── List documents ──
async function listDocs(config) {
  const docs = await request(`${config.server}/api/docs`);

  console.log(`\n📚 Documents (${docs.length}):\n`);
  docs.forEach((doc, i) => {
    console.log(`${i + 1}. ${doc.title}`);
    console.log(`   File: ${doc.file}`);
    if (doc.desc) console.log(`   ${doc.desc}`);
    console.log();
  });

  return docs;
}

// ── Init config ──
async function initConfig() {
  const defaultConfig = {
    server: 'http://localhost:3457',
    apiKey: 'dev-key-change-in-production',
  };

  const configPath = '.docsrc.json';
  await import('fs/promises').then(fs =>
    fs.writeFile(configPath, JSON.stringify(defaultConfig, null, 2), 'utf-8')
  );

  console.log(`✓ Created config file: ${configPath}`);
  console.log('\nEdit this file with your server URL and API key:');
  console.log(JSON.stringify(defaultConfig, null, 2));
}

// ── CLI ──
async function main() {
  const args = process.argv.slice(2);
  const command = args[0];

  if (!command || command === 'help') {
    console.log(`
📚 Docs Share CLI

Usage:
  docs-share <command> [options]

Commands:
  upload <file...>     Upload one or more markdown files
  delete <filename>    Delete a document from the server
  list                 List all documents on the server
  init                 Create a config file (.docsrc.json)
  help                 Show this help message

Config:
  Create a .docsrc.json file in your project or home directory:
  {
    "server": "http://your-server:3457",
    "apiKey": "your-api-key"
  }

Examples:
  docs-share upload doc.md
  docs-share upload *.md
  docs-share delete old-doc.md
  docs-share list
    `);
    return;
  }

  if (command === 'init') {
    await initConfig();
    return;
  }

  const config = await loadConfig();
  if (!config) {
    console.error('❌ Config file not found!');
    console.error('Run: docs-share init');
    process.exit(1);
  }

  try {
    switch (command) {
      case 'upload': {
        const files = args.slice(1);
        if (files.length === 0) {
          console.error('❌ No files specified');
          process.exit(1);
        }

        for (const file of files) {
          await uploadDoc(config, file);
        }
        break;
      }

      case 'delete': {
        const filename = args[1];
        if (!filename) {
          console.error('❌ No filename specified');
          process.exit(1);
        }
        await deleteDoc(config, filename);
        break;
      }

      case 'list': {
        await listDocs(config);
        break;
      }

      default:
        console.error(`❌ Unknown command: ${command}`);
        console.error('Run: docs-share help');
        process.exit(1);
    }
  } catch (error) {
    console.error(`❌ Error: ${error.message}`);
    process.exit(1);
  }
}

main();
