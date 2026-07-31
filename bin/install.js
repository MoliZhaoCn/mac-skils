#!/usr/bin/env node
/**
 * npx 入口 - macos-to-linux-compat
 *
 * 这个脚本被 npm/npx 调用，它做两件事:
 *   1. 把包内的 install.sh 和 SKILL.md 暴露给用户（通过环境变量）
 *   2. 在用户当前工作目录执行 bash 脚本（让相对路径 ./AGENTS.md 等生效）
 *
 * 用法:
 *   npx macos-to-linux-compat add claude-code
 *   npx macos-to-linux-compat remove aider
 *   npx macos-to-linux-compat list
 */

const { spawnSync } = require('child_process');
const path = require('path');
const fs = require('fs');

const scriptPath = path.join(__dirname, '..', 'install.sh');
const skillFile = path.join(__dirname, '..', 'SKILL.md');

if (!fs.existsSync(scriptPath)) {
    console.error('错误: 找不到 install.sh');
    console.error('请通过 npx 或 npm 调用此包');
    process.exit(1);
}

if (!fs.existsSync(skillFile)) {
    console.error('错误: 找不到 SKILL.md');
    process.exit(1);
}

// 让 install.sh 通过环境变量知道 SKILL.md 在哪
const env = {
    ...process.env,
    SKILL_FILE: skillFile,
};

// 在用户当前目录执行 install.sh
// stdio: 'inherit' 让用户能直接看到/输入
const result = spawnSync('bash', [scriptPath, ...process.argv.slice(2)], {
    stdio: 'inherit',
    env,
    cwd: process.cwd(),
});

process.exit(result.status || 0);