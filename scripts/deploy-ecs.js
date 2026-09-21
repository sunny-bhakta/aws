#!/usr/bin/env node

const { spawnSync } = require('node:child_process');
const path = require('node:path');

const rootDir = path.resolve(__dirname, '..');
const terraformDir = path.join(rootDir, 'terraform');

const args = process.argv.slice(2);

if (args.includes('--help') || args.includes('-h')) {
  console.log(`\nDeploy NestJS to ECS with one command.\n\nUsage:\n  npm run deploy\n  npm run deploy -- --tag <image-tag>\n  npm run deploy -- --skip-build\n\nOptions:\n  --tag <tag>      Use an explicit Docker image tag (default: current git SHA)\n  --skip-build     Skip local NestJS build before Docker build\n  --help, -h       Show this help message\n\nEnvironment (optional):\n  AWS_REGION       Default: ap-south-1\n  AWS_PROFILE      Default: devops-local\n  ECR_REPOSITORY   Default: devops-nestjs-app\n`);
  process.exit(0);
}

const skipBuild = args.includes('--skip-build');

function getArgValue(name) {
  const idx = args.indexOf(name);
  if (idx === -1 || idx === args.length - 1) {
    return undefined;
  }
  return args[idx + 1];
}

const explicitTag = getArgValue('--tag');

const config = {
  region: process.env.AWS_REGION || 'ap-south-1',
  profile: process.env.AWS_PROFILE || 'devops-local',
  repository: process.env.ECR_REPOSITORY || 'devops-nestjs-app',
};

const commandEnv = {
  ...process.env,
  AWS_REGION: config.region,
  AWS_PROFILE: config.profile,
};

function run(command, commandArgs, options = {}) {
  const pretty = `${command} ${commandArgs.join(' ')}`.trim();
  console.log(`\n> ${pretty}`);
  const result = spawnSync(command, commandArgs, {
    cwd: options.cwd || rootDir,
    stdio: options.stdio || 'inherit',
    env: options.env || commandEnv,
    input: options.input,
    encoding: 'utf8',
  });

  if (result.status !== 0) {
    process.exit(result.status || 1);
  }

  return result;
}

function runCapture(command, commandArgs, options = {}) {
  const pretty = `${command} ${commandArgs.join(' ')}`.trim();
  console.log(`\n> ${pretty}`);
  const result = spawnSync(command, commandArgs, {
    cwd: options.cwd || rootDir,
    stdio: 'pipe',
    env: options.env || commandEnv,
    encoding: 'utf8',
  });

  if (result.status !== 0) {
    if (result.stdout) process.stdout.write(result.stdout);
    if (result.stderr) process.stderr.write(result.stderr);
    process.exit(result.status || 1);
  }

  return (result.stdout || '').trim();
}

function resolveImageTag() {
  if (explicitTag) {
    return explicitTag;
  }

  const gitSha = runCapture('git', ['rev-parse', '--short=12', 'HEAD']);
  if (!gitSha) {
    console.error('Failed to resolve git SHA. Pass --tag <value> instead.');
    process.exit(1);
  }
  return gitSha;
}

const imageTag = resolveImageTag();

console.log('\n=== Deploy configuration ===');
console.log(`AWS_REGION:      ${config.region}`);
console.log(`AWS_PROFILE:     ${config.profile}`);
console.log(`ECR_REPOSITORY:  ${config.repository}`);
console.log(`IMAGE_TAG:       ${imageTag}`);

if (!skipBuild) {
  run('npm', ['run', 'build']);
}

const accountId = runCapture('aws', ['sts', 'get-caller-identity', '--query', 'Account', '--output', 'text']);
const registry = `${accountId}.dkr.ecr.${config.region}.amazonaws.com`;
const imageUri = `${registry}/${config.repository}:${imageTag}`;

const ecrPassword = runCapture('aws', ['ecr', 'get-login-password', '--region', config.region]);

run('docker', ['login', '--username', 'AWS', '--password-stdin', registry], {
  input: `${ecrPassword}\n`,
});

run('docker', ['build', '-t', imageUri, '.']);
run('docker', ['push', imageUri]);

run('terraform', ['init', '-input=false'], { cwd: terraformDir });
run('terraform', ['validate'], { cwd: terraformDir });
run(
  'terraform',
  ['apply', '-auto-approve', '-var', `container_image_tag=${imageTag}`],
  { cwd: terraformDir },
);

console.log('\n✅ Deployment completed successfully.');
console.log(`Deployed image: ${imageUri}`);
