#!/usr/bin/env node
'use strict';

/**
 * macos-to-linux-compat 一键安装器
 *
 * 用法:
 *   npx macos-to-linux-compat                      # 交互式，自动检测已安装的 AI 工具
 *   npx macos-to-linux-compat --tool=claude-code   # 非交互，仅安装到 Claude Code
 *   npx macos-to-linux-compat --tool=cursor,claude-code
 *   npx macos-to-linux-compat --all                # 强制安装到全部支持的工具
 *   npx macos-to-linux-compat --uninstall          # 卸载
 *
 * 支持目标: Claude Code / Cursor / Aider / Continue
 */

const fs = require('fs');
const path = require('path');
const os = require('os');
const readline = require('readline');

// ===== 路径 =====
const PKG_ROOT = path.resolve(__dirname, '..');
const SKILL_NAME = 'macos-to-linux-compat';
const SOURCE_SKILL = path.join(PKG_ROOT, 'SKILL.md');
const SOURCE_SCRIPTS = path.join(PKG_ROOT, 'scripts');
const SOURCE_REFS = path.join(PKG_ROOT, 'references');
const HOME = os.homedir();

// ===== 颜色（无 chalk 依赖）=====
const useColor = process.stdout.isTTY && !process.env.NO_COLOR;
const c = {
  red: s => useColor ? `\x1b[31m${s}\x1b[0m` : s,
  green: s => useColor ? `\x1b[32m${s}\x1b[0m` : s,
  yellow: s => useColor ? `\x1b[33m${s}\x1b[0m` : s,
  cyan: s => useColor ? `\x1b[36m${s}\x1b[0m` : s,
  dim: s => useColor ? `\x1b[2m${s}\x1b[0m` : s,
  bold: s => useColor ? `\x1b[1m${s}\x1b[0m` : s,
};

const log = {
  info: s => console.log(`${c.cyan('ℹ')}  ${s}`),
  ok:   s => console.log(`${c.green('✓')}  ${s}`),
  warn: s => console.log(`${c.yellow('⚠')}  ${s}`),
  err:  s => console.log(`${c.red('✗')}  ${s}`),
  dim:  s => console.log(c.dim(`   ${s}`)),
};

// ===== 参数解析 =====
const args = process.argv.slice(2);
const flags = {};
for (const arg of args) {
  if (arg.startsWith('--')) {
    const [k, v] = arg.slice(2).split('=');
    flags[k] = v === undefined ? true : v;
  }
}

// ===== 工具函数 =====
function ask(question, defaultValue = '') {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  const prompt = defaultValue ? `${question} [${defaultValue}]: ` : `${question}: `;
  return new Promise(resolve => {
    rl.question(prompt, ans => {
      rl.close();
      const v = ans.trim();
      resolve(v === '' ? defaultValue : v);
    });
  });
}

async function confirm(question, defaultYes = true) {
  const suffix = defaultYes ? ' [Y/n]' : ' [y/N]';
  const ans = await ask(question + suffix, '');
  if (ans === '') return defaultYes;
  return /^y|yes$/i.test(ans);
}

function copyDir(src, dest) {
  if (!fs.existsSync(src)) return;
  fs.mkdirSync(dest, { recursive: true });
  for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
    const s = path.join(src, entry.name);
    const d = path.join(dest, entry.name);
    if (entry.isDirectory()) copyDir(s, d);
    else fs.copyFileSync(s, d);
  }
}

function rmDir(dir) {
  if (!fs.existsSync(dir)) return false;
  fs.rmSync(dir, { recursive: true, force: true });
  return true;
}

function stripFrontmatter(content) {
  return content.replace(/^---[\s\S]*?---\n/, '');
}

function readIfExists(p) {
  return fs.existsSync(p) ? fs.readFileSync(p, 'utf8') : '';
}

// ===== 各工具安装逻辑 =====

function detectTools() {
  return {
    claudeCode: fs.existsSync(path.join(HOME, '.claude')),
    cursor: fs.existsSync(path.join(HOME, '.cursor')) ||
            fs.existsSync(path.join(HOME, 'Library/Application Support/Cursor')),
    aider: process.env.AIDER !== undefined ||
            fs.existsSync(path.join(process.cwd(), '.aider.conf.yml')),
    continue: fs.existsSync(path.join(HOME, '.continue')),
  };
}

async function installClaudeCode() {
  const dir = path.join(HOME, '.claude', 'skills', SKILL_NAME);
  fs.mkdirSync(dir, { recursive: true });
  fs.copyFileSync(SOURCE_SKILL, path.join(dir, 'SKILL.md'));
  copyDir(SOURCE_SCRIPTS, path.join(dir, 'scripts'));
  copyDir(SOURCE_REFS, path.join(dir, 'references'));
  log.ok(`Claude Code skill 已安装到: ${dir}`);

  // 询问是否同步追加核心规则到 ~/.claude/CLAUDE.md
  const claudeMd = path.join(HOME, '.claude', 'CLAUDE.md');
  const marker = '## 跨平台归档规则';
  const existing = readIfExists(claudeMd);
  if (existing.includes(marker)) {
    log.dim(`CLAUDE.md 已包含跨平台规则，跳过追加`);
    return;
  }

  const yes = await confirm(
    '同时把核心规则追加到 ~/.claude/CLAUDE.md（无需 Skill 调用即可生效）',
    true,
  );
  if (!yes) return;

  const rule = `

## 跨平台归档规则（始终生效 — 当前平台为 MacOS / Darwin）

任何生成或执行 \`tar\` 打包命令时，必须加：

\`\`\`
--no-acls --no-xattrs --no-fflags --no-mac-metadata
\`\`\`

Linux 端解压时建议加 \`--no-same-owner\`。

涉及 Dockerfile / docker-compose / CI/CD 配置、换源、国内构建慢等问题时，调用 Skill 工具加载 \`macos-to-linux-compat\` 获取详细规则。
`;
  fs.appendFileSync(claudeMd, rule);
  log.ok(`核心规则已追加到: ${claudeMd}`);
}

async function installCursor() {
  const projectDir = await ask('Cursor 项目路径', process.cwd());
  const target = path.join(projectDir, 'AGENTS.md');
  const content = stripFrontmatter(readIfExists(SOURCE_SKILL));
  fs.writeFileSync(target, readIfExists(target) + '\n\n' + content);
  log.ok(`已写入: ${target}`);
}

async function installAider() {
  const projectDir = await ask('Aider 项目路径', process.cwd());
  const target = path.join(projectDir, 'CONVENTIONS.md');
  const content = stripFrontmatter(readIfExists(SOURCE_SKILL));
  fs.writeFileSync(target, readIfExists(target) + '\n\n' + content);
  log.ok(`已写入: ${target}`);
}

async function installContinue() {
  const configPath = path.join(HOME, '.continue', 'config.json');
  fs.mkdirSync(path.dirname(configPath), { recursive: true });
  if (!fs.existsSync(configPath)) {
    fs.writeFileSync(configPath, '{}');
  }
  const config = JSON.parse(readIfExists(configPath) || '{}');
  const content = stripFrontmatter(readIfExists(SOURCE_SKILL));
  config.customInstructions = (config.customInstructions || '') + '\n\n' + content;
  fs.writeFileSync(configPath, JSON.stringify(config, null, 2));
  log.ok(`已写入: ${configPath}`);
}

// ===== 卸载逻辑 =====

function uninstallClaudeCode() {
  const dir = path.join(HOME, '.claude', 'skills', SKILL_NAME);
  if (rmDir(dir)) log.ok(`已删除: ${dir}`);
  else log.dim(`未找到: ${dir}`);

  const claudeMd = path.join(HOME, '.claude', 'CLAUDE.md');
  if (fs.existsSync(claudeMd)) {
    const content = fs.readFileSync(claudeMd, 'utf8');
    // 移除以 marker 开头的整段（直到下一个 ## 或文件结尾）
    const re = /\n## 跨平台归档规则[\s\S]*?(?=\n## |\n*$)/;
    const stripped = content.replace(re, '');
    if (stripped !== content) {
      fs.writeFileSync(claudeMd, stripped);
      log.ok(`已从 CLAUDE.md 移除跨平台规则`);
    } else {
      log.dim(`CLAUDE.md 中未找到跨平台规则段落`);
    }
  }
}

function uninstallCursor() {
  // Cursor 安装位置是项目级，只能提示用户手动删除 AGENTS.md 中的内容
  log.warn(`Cursor 安装为项目级，请手动清理各项目的 AGENTS.md 中的相关段落`);
}

function uninstallAider() {
  log.warn(`Aider 安装为项目级，请手动清理各项目的 CONVENTIONS.md 中的相关段落`);
}

function uninstallContinue() {
  const configPath = path.join(HOME, '.continue', 'config.json');
  if (!fs.existsSync(configPath)) return;
  const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  const before = config.customInstructions || '';
  // 移除包含 macos-to-linux-compat 标记的段落
  const stripped = before.replace(/\n\n# MacOS → Linux 兼容性助手[\s\S]*?(?=\n\n# |\n*$)/, '');
  if (stripped !== before) {
    config.customInstructions = stripped;
    fs.writeFileSync(configPath, JSON.stringify(config, null, 2));
    log.ok(`已从 Continue config.json 移除规则`);
  } else {
    log.dim(`Continue config.json 中未找到规则`);
  }
}

// ===== 工具清单 =====
const TOOLS = [
  {
    key: 'claude-code', name: 'Claude Code',
    detect: 'claudeCode',
    install: installClaudeCode,
    uninstall: uninstallClaudeCode,
  },
  {
    key: 'cursor', name: 'Cursor',
    detect: 'cursor',
    install: installCursor,
    uninstall: uninstallCursor,
  },
  {
    key: 'aider', name: 'Aider',
    detect: 'aider',
    install: installAider,
    uninstall: uninstallAider,
  },
  {
    key: 'continue', name: 'Continue (VS Code)',
    detect: 'continue',
    install: installContinue,
    uninstall: uninstallContinue,
  },
];

// ===== 主流程 =====

async function main() {
  console.log(c.bold('\n📦 macos-to-linux-compat 安装器\n'));

  if (!fs.existsSync(SOURCE_SKILL)) {
    log.err(`找不到源文件: ${SOURCE_SKILL}`);
    log.err('请通过 npx 或 npm 包方式运行本脚本，不要单独执行');
    process.exit(1);
  }

  if (os.platform() !== 'darwin') {
    log.warn(`当前平台: ${os.platform()}（非 MacOS），仍可继续但部分规则不适用`);
  }

  const detected = detectTools();
  log.info('检测结果:');
  for (const t of TOOLS) {
    const mark = detected[t.detect] ? c.green('✓') : c.dim('○');
    console.log(`   ${mark} ${t.name}`);
  }

  // 卸载模式
  if (flags.uninstall) {
    console.log('');
    let selected;
    if (flags.tool) {
      selected = flags.tool.split(',').map(s => s.trim());
    } else {
      const detectedKeys = TOOLS.filter(t => detected[t.detect]).map(t => t.key);
      selected = detectedKeys.length > 0 ? detectedKeys : TOOLS.map(t => t.key);
    }
    for (const key of selected) {
      const tool = TOOLS.find(t => t.key === key);
      if (!tool) { log.err(`未知工具: ${key}`); continue; }
      try { tool.uninstall(); } catch (e) { log.err(`${tool.name} 卸载失败: ${e.message}`); }
    }
    console.log('');
    log.ok('卸载完成');
    return;
  }

  // 安装模式：选择工具
  let selected;
  if (flags.tool) {
    selected = flags.tool.split(',').map(s => s.trim());
    log.info(`通过 --tool 指定: ${selected.join(', ')}`);
  } else if (flags.all) {
    selected = TOOLS.map(t => t.key);
    log.info('--all：安装到全部支持的工具');
  } else {
    console.log('');
    const detectedKeys = TOOLS.filter(t => detected[t.detect]).map(t => t.key);
    const defaultHint = detectedKeys.length > 0
      ? `留空 = 全选检测到的 [${detectedKeys.join(', ')}]`
      : '留空 = 全部安装';

    TOOLS.forEach((t, i) => {
      const mark = detected[t.detect] ? c.green('✓') : c.dim('○');
      console.log(`   ${mark} ${i + 1}. ${t.name}`);
    });

    const ans = await ask(`\n选择要安装的工具 (1-${TOOLS.length}, 逗号分隔, ${defaultHint})`, '');

    if (ans === '') {
      selected = detectedKeys.length > 0 ? detectedKeys : TOOLS.map(t => t.key);
    } else {
      selected = ans.split(',')
        .map(s => TOOLS[parseInt(s.trim()) - 1]?.key)
        .filter(Boolean);
    }
  }

  if (selected.length === 0) {
    log.warn('未选择任何工具，退出');
    process.exit(0);
  }

  console.log('');
  for (const key of selected) {
    const tool = TOOLS.find(t => t.key === key);
    if (!tool) { log.err(`未知工具: ${key}`); continue; }
    try {
      await tool.install();
    } catch (err) {
      log.err(`${tool.name} 安装失败: ${err.message}`);
    }
  }

  console.log('');
  log.ok('安装完成！');
  log.info('重启你的 AI 工具以加载 skill。');
  console.log('');
  log.info('验证安装:');
  console.log(c.dim(`   bash ~/.claude/skills/${SKILL_NAME}/scripts/detect-macos.sh`));
  console.log(c.dim(`   bash ~/.claude/skills/${SKILL_NAME}/scripts/verify-archive.sh your-archive.tar.gz`));
  console.log('');
}

main().catch(err => {
  log.err(err.message);
  process.exit(1);
});
