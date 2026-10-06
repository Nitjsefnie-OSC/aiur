#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const packageRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

export function build(outputDir = path.join(packageRoot, 'dist')) {
  fs.rmSync(outputDir, { recursive: true, force: true });
  fs.mkdirSync(path.join(outputDir, 'css'), { recursive: true });
  execFileSync(path.join(packageRoot, 'node_modules/.bin/tsc'),
    ['--project', path.join(packageRoot, 'tsconfig.json'), '--outDir', path.join(outputDir, 'js')],
    { cwd: packageRoot, stdio: 'inherit' });
  const cssDir = path.join(packageRoot, 'src/css');
  const cssFiles = fs.readdirSync(cssDir).filter(file => file.endsWith('.css')).sort();
  const contents = cssFiles.map(file => {
    const css = fs.readFileSync(path.join(cssDir, file), 'utf8').replace(/\r\n/g, '\n');
    // Individual CSS lives one directory deeper than the consolidated stylesheet.
    fs.writeFileSync(path.join(outputDir, 'css', file), css.replaceAll("'./fonts/", "'../fonts/"));
    return css;
  });
  fs.writeFileSync(path.join(outputDir, 'aiur-style.css'), contents.join('\n'));
  fs.copyFileSync(path.join(cssDir, 'fonts.css'), path.join(outputDir, 'fonts.css'));
  for (const directory of ['fonts', 'assets']) {
    fs.cpSync(path.join(packageRoot, directory), path.join(outputDir, directory), { recursive: true });
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  build();
  console.log('✓ Build complete');
}
