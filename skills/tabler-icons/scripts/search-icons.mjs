#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { createRequire } from 'node:module';

const PACKAGE_PRIORITY = [
  '@tabler/icons-svelte-runes',
  '@tabler/icons-svelte',
  '@tabler/icons-astro',
  '@tabler/icons-react',
  '@tabler/icons-vue',
  '@tabler/icons-preact',
  '@tabler/icons-solidjs',
  '@tabler/icons',
];

const COMPONENT_PACKAGES = new Set(PACKAGE_PRIORITY.filter((name) => name !== '@tabler/icons'));

function fail(message, exitCode = 1) {
  console.error(`[tabler-icons] ${message}`);
  process.exit(exitCode);
}

function usage() {
  console.log(`Tabler Icons installed-catalog search

Usage:
  search-icons.mjs search <terms...> [options]
  search-icons.mjs verify <icon-names...> [options]

Options:
  --project DIR       Project directory or a child directory (default: cwd)
  --package NAME      Force an official @tabler icon package
  --metadata FILE     Force an icons.json file
  --style STYLE       outline, filled, or any (default: any)
  --limit NUMBER      Search result limit, 1-50 (default: 10)
  --json              Emit machine-readable JSON
  -h, --help          Show this help

Examples:
  search-icons.mjs search save disk --project . --json
  search-icons.mjs search favorite selected --style filled
  search-icons.mjs verify IconDeviceFloppy IconHeartFilled --project .
`);
}

function parseArgs(argv) {
  const args = [...argv];
  let command = 'search';

  if (args[0] === 'search' || args[0] === 'verify') {
    command = args.shift();
  }

  const options = {
    project: process.cwd(),
    packageName: null,
    metadata: null,
    style: 'any',
    limit: 10,
    json: false,
    help: false,
  };
  const values = [];

  while (args.length > 0) {
    const arg = args.shift();

    switch (arg) {
      case '--project':
        options.project = args.shift() ?? fail('--projectにはディレクトリが必要です。');
        break;
      case '--package':
        options.packageName = args.shift() ?? fail('--packageにはパッケージ名が必要です。');
        break;
      case '--metadata':
        options.metadata = args.shift() ?? fail('--metadataにはファイルパスが必要です。');
        break;
      case '--style':
        options.style = args.shift() ?? fail('--styleには値が必要です。');
        break;
      case '--limit': {
        const raw = args.shift() ?? fail('--limitには数値が必要です。');
        options.limit = Number.parseInt(raw, 10);
        break;
      }
      case '--json':
        options.json = true;
        break;
      case '-h':
      case '--help':
        options.help = true;
        break;
      default:
        if (arg.startsWith('-')) {
          fail(`不明なオプションです: ${arg}`);
        }
        values.push(arg);
    }
  }

  if (!['outline', 'filled', 'any'].includes(options.style)) {
    fail(`--styleはoutline、filled、anyのいずれかです: ${options.style}`);
  }
  if (!Number.isInteger(options.limit) || options.limit < 1 || options.limit > 50) {
    fail('--limitは1〜50の整数です。');
  }
  if (options.packageName && !PACKAGE_PRIORITY.includes(options.packageName)) {
    fail(`未対応のパッケージです: ${options.packageName}`);
  }

  return { command, options, values };
}

function readJson(filePath) {
  try {
    return JSON.parse(fs.readFileSync(filePath, 'utf8'));
  } catch (error) {
    fail(`JSONを読めません: ${filePath}\n${error.message}`);
  }
}

function findProjectRoot(startPath) {
  let current = path.resolve(startPath);

  if (!fs.existsSync(current)) {
    fail(`--projectが存在しません: ${current}`);
  }
  if (!fs.statSync(current).isDirectory()) {
    current = path.dirname(current);
  }

  while (true) {
    if (fs.existsSync(path.join(current, 'package.json'))) {
      return current;
    }
    const parent = path.dirname(current);
    if (parent === current) {
      return path.resolve(startPath);
    }
    current = parent;
  }
}

function dependenciesOf(packageJson) {
  return {
    ...(packageJson.dependencies ?? {}),
    ...(packageJson.devDependencies ?? {}),
    ...(packageJson.peerDependencies ?? {}),
    ...(packageJson.optionalDependencies ?? {}),
  };
}

function detectPackage(projectRoot, forcedPackage) {
  if (forcedPackage) {
    return forcedPackage;
  }

  const packageJsonPath = path.join(projectRoot, 'package.json');
  const packageJson = fs.existsSync(packageJsonPath) ? readJson(packageJsonPath) : {};
  const dependencies = dependenciesOf(packageJson);

  for (const packageName of PACKAGE_PRIORITY) {
    if (Object.hasOwn(dependencies, packageName)) {
      return packageName;
    }
  }

  if (fs.existsSync(path.join(projectRoot, 'node_modules', '@tabler', 'icons', 'icons.json'))) {
    return '@tabler/icons';
  }

  return null;
}

function packagePath(projectRoot, packageName) {
  return path.join(projectRoot, 'node_modules', ...packageName.split('/'));
}

function findPackageDir(projectRoot, packageName) {
  const direct = packagePath(projectRoot, packageName);
  if (fs.existsSync(path.join(direct, 'package.json'))) {
    return fs.realpathSync(direct);
  }

  const projectPackage = path.join(projectRoot, 'package.json');
  try {
    const requireFromProject = createRequire(
      fs.existsSync(projectPackage) ? projectPackage : path.join(projectRoot, '__tabler_search__.cjs'),
    );

    for (const request of [`${packageName}/package.json`, packageName]) {
      try {
        const resolved = requireFromProject.resolve(request);
        let current = fs.statSync(resolved).isDirectory() ? resolved : path.dirname(resolved);

        while (true) {
          const candidate = path.join(current, 'package.json');
          if (fs.existsSync(candidate)) {
            const metadata = readJson(candidate);
            if (metadata.name === packageName) {
              return fs.realpathSync(current);
            }
          }
          const parent = path.dirname(current);
          if (parent === current) {
            break;
          }
          current = parent;
        }
      } catch {
        // Try the next resolution route.
      }
    }
  } catch {
    // A project without package.json can still use the direct or pnpm path.
  }

  const pnpmRoot = path.join(projectRoot, 'node_modules', '.pnpm');
  if (fs.existsSync(pnpmRoot)) {
    const prefix = packageName.replace(/^@/, '').replace('/', '+') + '@';

    for (const entry of fs.readdirSync(pnpmRoot).filter((name) => name.startsWith(prefix)).sort()) {
      const candidate = path.join(pnpmRoot, entry, 'node_modules', ...packageName.split('/'));
      if (fs.existsSync(path.join(candidate, 'package.json'))) {
        return fs.realpathSync(candidate);
      }
    }
  }

  return null;
}

function addCandidate(candidates, candidate) {
  if (candidate && !candidates.includes(candidate)) {
    candidates.push(candidate);
  }
}

function findCoreMetadata(projectRoot, selectedPackage, forcedMetadata, selectedPackageDir = null) {
  if (forcedMetadata) {
    const explicit = path.resolve(projectRoot, forcedMetadata);
    if (!fs.existsSync(explicit)) {
      fail(`--metadataが存在しません: ${explicit}`);
    }
    return explicit;
  }

  const candidates = [];
  addCandidate(candidates, path.join(projectRoot, 'node_modules', '@tabler', 'icons', 'icons.json'));

  const selectedDir =
    selectedPackageDir ?? (selectedPackage ? findPackageDir(projectRoot, selectedPackage) : null);
  if (selectedPackage === '@tabler/icons' && selectedDir) {
    addCandidate(candidates, path.join(selectedDir, 'icons.json'));
  }

  if (selectedDir) {
    let current = selectedDir;

    while (true) {
      addCandidate(candidates, path.join(current, 'node_modules', '@tabler', 'icons', 'icons.json'));
      const parent = path.dirname(current);
      if (parent === current) {
        break;
      }
      current = parent;
    }
  }

  const pnpmRoot = path.join(projectRoot, 'node_modules', '.pnpm');
  if (fs.existsSync(pnpmRoot)) {
    for (const entry of fs.readdirSync(pnpmRoot).filter((name) => name.startsWith('@tabler+icons@')).sort()) {
      addCandidate(
        candidates,
        path.join(pnpmRoot, entry, 'node_modules', '@tabler', 'icons', 'icons.json'),
      );
    }
  }

  return candidates.find((candidate) => fs.existsSync(candidate)) ?? null;
}

function normalizeTerms(values) {
  return values
    .flatMap((value) => value.toLowerCase().split(/[^a-z0-9]+/u))
    .filter(Boolean);
}

function pascalToKebab(value) {
  return value
    .replace(/([A-Z]+)([A-Z][a-z])/g, '$1-$2')
    .replace(/([a-z0-9])([A-Z])/g, '$1-$2')
    .replace(/_/g, '-')
    .toLowerCase();
}

function normalizeIconInput(raw, defaultStyle = 'outline') {
  let value = raw.trim();
  let style = defaultStyle === 'any' ? 'outline' : defaultStyle;

  if (value.startsWith('Icon')) {
    value = value.slice(4);
    if (value.endsWith('Filled')) {
      value = value.slice(0, -6);
      style = 'filled';
    }
    value = pascalToKebab(value);
  } else {
    value = value.toLowerCase();
    if (value.endsWith('-filled')) {
      value = value.slice(0, -7);
      style = 'filled';
    }
  }

  return { name: value, style };
}

function toPascalCase(value) {
  return value
    .split('-')
    .filter(Boolean)
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join('');
}

function componentName(name, style) {
  return `Icon${toPascalCase(name)}${style === 'filled' ? 'Filled' : ''}`;
}

function importTarget(packageName, name, style) {
  if (packageName === '@tabler/icons') {
    return `@tabler/icons/${style}/${name}.svg`;
  }

  return packageName ? componentName(name, style) : null;
}

function availableStyles(icon) {
  return Object.keys(icon.styles ?? {});
}

function normalizeTags(tags) {
  if (Array.isArray(tags)) {
    return tags.map((tag) => String(tag).toLowerCase());
  }
  if (typeof tags === 'string') {
    return tags.toLowerCase().split(/[\s,]+/u).filter(Boolean);
  }
  return [];
}

function scoreIcon(icon, terms) {
  const name = String(icon.name ?? '').toLowerCase();
  const segments = name.split('-');
  const tags = normalizeTags(icon.tags);
  const category = String(icon.category ?? '').toLowerCase();
  const phrase = terms.join('-');
  let score = 0;

  if (name === phrase) {
    score += 160;
  } else if (phrase && name.includes(phrase)) {
    score += 70;
  }

  for (const term of terms) {
    if (segments.includes(term)) {
      score += 38;
    } else if (name.startsWith(term)) {
      score += 24;
    } else if (name.includes(term)) {
      score += 14;
    }

    if (tags.includes(term)) {
      score += 32;
    } else if (tags.some((tag) => tag.includes(term))) {
      score += 12;
    }

    if (category === term) {
      score += 18;
    } else if (category.includes(term)) {
      score += 7;
    }
  }

  return score;
}

function loadCatalog(metadataPath) {
  const raw = readJson(metadataPath);

  if (!raw || Array.isArray(raw) || typeof raw !== 'object') {
    fail(`icons.jsonの形式が不正です: ${metadataPath}`);
  }

  return Object.entries(raw).map(([key, value]) => ({
    ...value,
    name: value?.name ?? key,
  }));
}

function coreVersion(metadataPath) {
  const packageJsonPath = path.join(path.dirname(metadataPath), 'package.json');
  if (!fs.existsSync(packageJsonPath)) {
    return null;
  }
  return readJson(packageJsonPath).version ?? null;
}

function installedPackageVersion(packageDir) {
  if (!packageDir) {
    return null;
  }

  const packageJsonPath = path.join(packageDir, 'package.json');
  if (!fs.existsSync(packageJsonPath)) {
    return null;
  }

  return readJson(packageJsonPath).version ?? null;
}

function parseGeneratedStringArray(filePath) {
  const content = fs.readFileSync(filePath, 'utf8');
  const start = content.indexOf('[');
  const end = content.lastIndexOf(']');

  if (start < 0 || end <= start) {
    return null;
  }

  try {
    const parsed = JSON.parse(content.slice(start, end + 1));
    return Array.isArray(parsed) && parsed.every((item) => typeof item === 'string')
      ? parsed
      : null;
  } catch {
    return null;
  }
}

function loadAdapterIconCatalog(packageDir) {
  if (!packageDir) {
    return null;
  }

  const candidates = [
    path.join(packageDir, 'dist', 'icons-list.js'),
    path.join(packageDir, 'dist', 'icons-list.mjs'),
    path.join(packageDir, 'dist', 'esm', 'icons-list.mjs'),
    path.join(packageDir, 'dist', 'cjs', 'icons-list.cjs'),
    path.join(packageDir, 'src', 'icons-list.ts'),
    path.join(packageDir, 'src', 'icons-list.js'),
  ];

  for (const candidate of candidates) {
    if (!fs.existsSync(candidate)) {
      continue;
    }

    const values = parseGeneratedStringArray(candidate);
    if (values) {
      return {
        path: candidate,
        icons: new Set(values),
      };
    }
  }

  return null;
}

function adapterIconKey(name, style) {
  return `${name}${style === 'filled' ? '-filled' : ''}`;
}

function makeResult(icon, packageName, style, adapterCatalog, score = null) {
  const component = COMPONENT_PACKAGES.has(packageName) ? componentName(icon.name, style) : null;
  const result = {
    name: icon.name,
    style,
    component,
    import:
      packageName === '@tabler/icons'
        ? importTarget(packageName, icon.name, style)
        : packageName
          ? `import { ${component} } from '${packageName}';`
          : null,
    category: icon.category ?? '',
    tags: normalizeTags(icon.tags),
    styles: availableStyles(icon),
    filledAvailable: Boolean(icon.styles?.filled),
    verifiedBy: adapterCatalog
      ? [
          'installed @tabler/icons/icons.json',
          'installed adapter icons-list',
        ]
      : ['installed @tabler/icons/icons.json'],
  };

  if (score !== null) {
    result.score = score;
  }

  return result;
}

function search(catalog, packageName, style, terms, limit, adapterCatalog) {
  const requestedStyle = style === 'any' ? 'outline' : style;

  return catalog
    .filter((icon) => Boolean(icon.styles?.[requestedStyle]))
    .filter(
      (icon) =>
        !adapterCatalog ||
        adapterCatalog.icons.has(adapterIconKey(icon.name, requestedStyle)),
    )
    .map((icon) => ({
      icon,
      score: scoreIcon(icon, terms),
    }))
    .filter(({ score }) => score > 0)
    .sort((a, b) => b.score - a.score || a.icon.name.localeCompare(b.icon.name))
    .slice(0, limit)
    .map(({ icon, score }) =>
      makeResult(icon, packageName, requestedStyle, adapterCatalog, score),
    );
}

function verify(catalog, packageName, defaultStyle, values, adapterCatalog) {
  const byName = new Map(catalog.map((icon) => [icon.name, icon]));
  const byComponent = new Map();

  for (const icon of catalog) {
    for (const style of availableStyles(icon)) {
      byComponent.set(componentName(icon.name, style), { icon, style });
    }
  }

  return values.map((raw) => {
    let icon;
    let style;
    let normalized;

    if (raw.startsWith('Icon')) {
      const requestedComponent =
        defaultStyle === 'filled' && !raw.endsWith('Filled') ? `${raw}Filled` : raw;
      const match = byComponent.get(requestedComponent);

      if (match) {
        ({ icon, style } = match);
        normalized = { name: icon.name, style };
      } else {
        normalized = normalizeIconInput(raw, defaultStyle);
        icon = byName.get(normalized.name);
        style = normalized.style;
      }
    } else {
      normalized = normalizeIconInput(raw, defaultStyle);
      icon = byName.get(normalized.name);
      style = normalized.style;
    }

    const styleExists = Boolean(icon?.styles?.[style]);
    if (!icon || !styleExists) {
      return {
        input: raw,
        exists: false,
        name: normalized.name,
        style,
        reason: !icon ? 'canonical icon not found' : `${style} style not found`,
      };
    }

    if (adapterCatalog && !adapterCatalog.icons.has(adapterIconKey(icon.name, style))) {
      return {
        input: raw,
        exists: false,
        name: icon.name,
        style,
        reason: 'icon is not exported by the installed framework adapter',
      };
    }

    return {
      input: raw,
      exists: true,
      ...makeResult(icon, packageName, style, adapterCatalog),
    };
  });
}

function printSearchHuman(context, results) {
  console.log(`project: ${context.project}`);
  console.log(`package: ${context.packageName ?? '(not detected)'}`);
  console.log(`package version: ${context.packageVersion ?? '(unknown)'}`);
  console.log(`catalog version: ${context.catalogVersion ?? '(unknown)'}`);
  console.log(`metadata: ${context.metadata}`);
  console.log(`adapter catalog: ${context.adapterCatalog ?? '(not available)'}`);
  console.log('');

  if (results.length === 0) {
    console.log('一致するアイコンはありません。検索語を変えてください。');
    return;
  }

  for (const result of results) {
    const identifier = result.component ?? result.import;
    const filled = result.filledAvailable ? 'filled=yes' : 'filled=no';
    console.log(`${identifier}\t${result.name}\t${result.category || '-'}\t${filled}\tscore=${result.score}`);
  }
}

function printVerifyHuman(context, results) {
  console.log(`project: ${context.project}`);
  console.log(`package: ${context.packageName ?? '(not detected)'}`);
  console.log(`package version: ${context.packageVersion ?? '(unknown)'}`);
  console.log(`catalog version: ${context.catalogVersion ?? '(unknown)'}`);
  console.log(`metadata: ${context.metadata}`);
  console.log(`adapter catalog: ${context.adapterCatalog ?? '(not available)'}`);
  console.log('');

  for (const result of results) {
    if (result.exists) {
      console.log(`OK\t${result.input}\t${result.name}\t${result.style}\t${result.import}`);
    } else {
      console.log(`NG\t${result.input}\t${result.name}\t${result.style}\t${result.reason}`);
    }
  }
}

const { command, options, values } = parseArgs(process.argv.slice(2));

if (options.help) {
  usage();
  process.exit(0);
}
if (values.length === 0) {
  usage();
  fail(command === 'verify' ? '確認するアイコン名がありません。' : '検索語がありません。');
}

const projectRoot = findProjectRoot(options.project);
const selectedPackage = detectPackage(projectRoot, options.packageName);
const selectedPackageDir = selectedPackage
  ? findPackageDir(projectRoot, selectedPackage)
  : null;
const metadataPath = findCoreMetadata(
  projectRoot,
  selectedPackage,
  options.metadata,
  selectedPackageDir,
);

if (!metadataPath) {
  fail(
    [
      '対象プロジェクトから@tabler/icons/icons.jsonを見つけられません。',
      '依存関係をインストール済みか、--projectが正しいか確認してください。',
      '特殊な配置では--metadata /path/to/icons.jsonを指定してください。',
    ].join('\n'),
    2,
  );
}

const catalog = loadCatalog(metadataPath);
const adapterCatalog = COMPONENT_PACKAGES.has(selectedPackage)
  ? loadAdapterIconCatalog(selectedPackageDir)
  : null;
const context = {
  project: projectRoot,
  packageName: selectedPackage,
  packageVersion: installedPackageVersion(selectedPackageDir),
  catalogVersion: coreVersion(metadataPath),
  metadata: metadataPath,
  adapterCatalog: adapterCatalog?.path ?? null,
};

if (command === 'search') {
  const terms = normalizeTerms(values);
  if (terms.length === 0) {
    fail('英数字の検索語がありません。UI意図を英語の名詞・動詞へ変換してください。');
  }

  const results = search(
    catalog,
    selectedPackage,
    options.style,
    terms,
    options.limit,
    adapterCatalog,
  );
  if (options.json) {
    console.log(JSON.stringify({ ...context, query: terms, style: options.style, results }, null, 2));
  } else {
    printSearchHuman(context, results);
  }
  process.exit(results.length > 0 ? 0 : 3);
}

const results = verify(
  catalog,
  selectedPackage,
  options.style,
  values,
  adapterCatalog,
);
if (options.json) {
  console.log(JSON.stringify({ ...context, results }, null, 2));
} else {
  printVerifyHuman(context, results);
}
process.exit(results.every((result) => result.exists) ? 0 : 4);
