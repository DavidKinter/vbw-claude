#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const os = require('os');

const args = process.argv.slice(2);
const isGlobal = args.includes('--global');
const isLocal = args.includes('--local') || !isGlobal;

// Determine target directory
const targetBase = isGlobal
  ? path.join(os.homedir(), '.claude')
  : path.join(process.cwd(), '.claude');

const commandsTarget = path.join(targetBase, 'commands');
const settingsTarget = path.join(targetBase, 'settings');

// Source directories (relative to this script)
const packageRoot = path.join(__dirname, '..');
const commandsSource = path.join(packageRoot, 'commands');
const settingsSource = path.join(packageRoot, 'settings');

// Create target directories
fs.mkdirSync(commandsTarget, { recursive: true });
fs.mkdirSync(settingsTarget, { recursive: true });

// Copy function
function copyDir(src, dest, prefix) {
  if (!fs.existsSync(src)) {
    console.log(`  Skipping ${prefix} (source not found)`);
    return 0;
  }

  const files = fs.readdirSync(src);
  let count = 0;

  for (const file of files) {
    const srcPath = path.join(src, file);
    const destPath = path.join(dest, file);

    if (fs.statSync(srcPath).isFile()) {
      fs.copyFileSync(srcPath, destPath);
      count++;
    }
  }

  return count;
}

console.log('VBW Framework Installer');
console.log('=======================');
console.log(`Target: ${targetBase}`);
console.log('');

const commandCount = copyDir(commandsSource, commandsTarget, 'commands');
console.log(`  Copied ${commandCount} command files to ${commandsTarget}`);

const settingsCount = copyDir(settingsSource, settingsTarget, 'settings');
console.log(`  Copied ${settingsCount} settings files to ${settingsTarget}`);

console.log('');
console.log('Done. Available commands:');
console.log('  /vbw-implement  - Start validated task');
console.log('  /vbw-execute    - Run in sandbox');
console.log('  /vbw-team       - Multi-role validation');
console.log('');
