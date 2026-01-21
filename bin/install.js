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
const utilsTarget = path.join(targetBase, 'utils');
const agentsTarget = path.join(targetBase, 'agents');

// Source directories (relative to this script)
const packageRoot = path.join(__dirname, '..');
const commandsSource = path.join(packageRoot, 'commands');
const settingsSource = path.join(packageRoot, 'settings');
const utilsSource = path.join(packageRoot, 'utils');
const agentsSource = path.join(packageRoot, 'agents');

// Create target directories
fs.mkdirSync(commandsTarget, { recursive: true });
fs.mkdirSync(settingsTarget, { recursive: true });
fs.mkdirSync(utilsTarget, { recursive: true });
fs.mkdirSync(agentsTarget, { recursive: true });

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
console.log(`  Copied ${commandCount} command files`);

const settingsCount = copyDir(settingsSource, settingsTarget, 'settings');
console.log(`  Copied ${settingsCount} settings files`);

const utilsCount = copyDir(utilsSource, utilsTarget, 'utils');
console.log(`  Copied ${utilsCount} utility scripts`);

const agentsCount = copyDir(agentsSource, agentsTarget, 'agents');
console.log(`  Copied ${agentsCount} agent files`);

// Make shell scripts executable
const utilsFiles = fs.existsSync(utilsTarget) ? fs.readdirSync(utilsTarget) : [];
for (const file of utilsFiles) {
  if (file.endsWith('.sh')) {
    const scriptPath = path.join(utilsTarget, file);
    fs.chmodSync(scriptPath, '755');
  }
}

console.log('');
console.log('Done. Available commands:');
console.log('  /vbw-implement  - Start validated task');
console.log('  /vbw-team       - Multi-role validation');
console.log('');
console.log('Installed subagents:');
console.log('  vbw-execute     - Sandbox execution (auto-invoked by Task tool)');
console.log('');
console.log('Supported languages: Python, TypeScript, Go, Java, C#, Ruby, PHP, Rust, Swift, Kotlin, C/C++');
console.log('');
