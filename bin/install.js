#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const os = require('os');

const args = process.argv.slice(2);
const isGlobal = args.includes('--global');
const isLocal = args.includes('--local') || !isGlobal;
const withHooks = args.includes('--with-hooks');
const showHelp = args.includes('--help') || args.includes('-h');

if (showHelp) {
  console.log(`
VBW Framework Installer
=======================

Usage: npx vbw-claude [options]

Options:
  --local       Install to current project's .claude/ directory (default)
  --global      Install to ~/.claude/ for all projects
  --with-hooks  Install native enforcement hooks (recommended)
  --help, -h    Show this help message

Examples:
  npx vbw-claude --local              # Install commands only
  npx vbw-claude --local --with-hooks # Install commands + hooks (recommended)
  npx vbw-claude --global             # Install globally for all projects

Hooks (--with-hooks):
  VBW provides two native enforcement hooks:

  1. vbw-execution-gate.sh (Stop hook)
     Ensures Claude actually runs code (docker build, pytest, etc.)
     before reporting success. Prevents "PASS without execution" failures.

  2. vbw-copy-gate.sh (PreToolUse hook)
     Blocks copying files from shadow to project without explicit
     user approval via AskUserQuestion.

  These hooks are RECOMMENDED for full VBW protection.
`);
  process.exit(0);
}

// Determine target directory
const targetBase = isGlobal
  ? path.join(os.homedir(), '.claude')
  : path.join(process.cwd(), '.claude');

const commandsTarget = path.join(targetBase, 'commands');
const settingsTarget = path.join(targetBase, 'settings');
const utilsTarget = path.join(targetBase, 'utils');
const agentsTarget = path.join(targetBase, 'agents');
const hooksTarget = path.join(targetBase, 'hooks');

// Source directories (relative to this script)
const packageRoot = path.join(__dirname, '..');
const commandsSource = path.join(packageRoot, 'commands');
const settingsSource = path.join(packageRoot, 'settings');
const utilsSource = path.join(packageRoot, 'utils');
const agentsSource = path.join(packageRoot, 'agents');
const hooksSource = path.join(packageRoot, 'hooks');

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

// Deep merge function for settings.json
function deepMerge(target, source) {
  const result = { ...target };

  for (const key of Object.keys(source)) {
    if (source[key] && typeof source[key] === 'object' && !Array.isArray(source[key])) {
      // Recursively merge objects
      result[key] = deepMerge(result[key] || {}, source[key]);
    } else if (Array.isArray(source[key])) {
      // For arrays (like hook arrays), merge without duplicates
      result[key] = mergeHookArrays(result[key] || [], source[key]);
    } else {
      result[key] = source[key];
    }
  }

  return result;
}

// Merge hook arrays without duplicating entries
function mergeHookArrays(existing, incoming) {
  const result = [...existing];

  for (const item of incoming) {
    // Check if this hook config already exists (by command path)
    const isDuplicate = result.some(existingItem => {
      if (existingItem.hooks && item.hooks) {
        return existingItem.hooks.some(eh =>
          item.hooks.some(ih => eh.command === ih.command)
        );
      }
      return false;
    });

    if (!isDuplicate) {
      result.push(item);
    }
  }

  return result;
}

// Install hooks into settings.json
function installHooksConfig(settingsPath) {
  let existingSettings = {};

  // Read existing settings if present
  if (fs.existsSync(settingsPath)) {
    try {
      const content = fs.readFileSync(settingsPath, 'utf8');
      existingSettings = JSON.parse(content);
    } catch (err) {
      console.log(`  Warning: Could not parse existing settings.json, backing up...`);
      const backupPath = settingsPath + '.backup.' + Date.now();
      fs.copyFileSync(settingsPath, backupPath);
      console.log(`  Backup created: ${backupPath}`);
      existingSettings = {};
    }
  }

  // VBW hook configuration
  const vbwHooks = {
    hooks: {
      Stop: [
        {
          hooks: [
            {
              type: "command",
              command: ".claude/hooks/vbw-execution-gate.sh"
            }
          ]
        }
      ],
      PreToolUse: [
        {
          matcher: "Bash",
          hooks: [
            {
              type: "command",
              command: ".claude/hooks/vbw-copy-gate.sh"
            }
          ]
        }
      ]
    }
  };

  // Deep merge
  const mergedSettings = deepMerge(existingSettings, vbwHooks);

  // Write back
  fs.writeFileSync(settingsPath, JSON.stringify(mergedSettings, null, 2) + '\n');

  return true;
}

console.log('VBW Framework Installer');
console.log('=======================');
console.log(`Target: ${targetBase}`);
console.log(`Hooks: ${withHooks ? 'Yes (--with-hooks)' : 'No (use --with-hooks to enable)'}`);
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

// Install hooks if requested
if (withHooks) {
  console.log('');
  console.log('Installing hooks...');

  // Create hooks directory
  fs.mkdirSync(hooksTarget, { recursive: true });

  // Copy hook files
  const hooksCount = copyDir(hooksSource, hooksTarget, 'hooks');
  console.log(`  Copied ${hooksCount} hook files`);

  // Make hooks executable
  const hookFiles = fs.existsSync(hooksTarget) ? fs.readdirSync(hooksTarget) : [];
  for (const file of hookFiles) {
    if (file.endsWith('.sh')) {
      const scriptPath = path.join(hooksTarget, file);
      fs.chmodSync(scriptPath, '755');
    }
  }
  console.log(`  Made ${hookFiles.filter(f => f.endsWith('.sh')).length} hooks executable`);

  // Merge hook config into settings.json
  const settingsJsonPath = path.join(targetBase, 'settings.json');
  installHooksConfig(settingsJsonPath);
  console.log(`  Merged hook config into settings.json`);

  console.log('');
  console.log('Hooks installed:');
  console.log('  ✓ vbw-execution-gate.sh (Stop)');
  console.log('      Ensures code execution before completion');
  console.log('  ✓ vbw-copy-gate.sh (PreToolUse)');
  console.log('      Blocks unauthorized shadow→project copies');
}

console.log('');
console.log('Done. Available commands:');
console.log('  /vbw-implement  - Start validated task');
console.log('  /vbw-team       - Multi-role validation');
console.log('');
console.log('Installed subagents:');
console.log('  vbw-execute     - Sandbox execution (auto-invoked by Task tool)');
console.log('');

if (!withHooks) {
  console.log('TIP: Run with --with-hooks for full VBW protection:');
  console.log('  npx vbw-claude --local --with-hooks');
  console.log('');
}

console.log('Supported languages: Python, TypeScript, Go, Java, C#, Ruby, PHP, Rust, Swift, Kotlin, C/C++');
console.log('');
