# NestJS AWS DevOps Starter

A production-style NestJS starter focused on CI/CD with GitHub Actions, Docker, Amazon ECR, and Amazon ECS.

## Overview

This project includes:

- NestJS API in TypeScript
- Health endpoint for container/service checks: `/health`
- Unit + e2e tests with Jest
- ESLint (flat config) for TS/JS
- Multi-stage `Dockerfile`
- GitHub Actions pipeline:
	- Lint + build + test
	- Docker build + smoke test
	- Push image to ECR
	- Deploy ECS service (force new deployment)

## Project structure

- `src/` - app source code
- `test/` - e2e tests
- `.github/workflows/ci.yml` - CI/CD workflow
- `Dockerfile` - production image build
- `docs/README.md` - AWS setup and deployment notes

## Prerequisites

- Node.js `22+`
- npm `10+`
- Docker (for local container build/test)
- AWS account (for ECR/ECS deployment)

## Local development

```bat
npm ci
npm run start:dev
```

App URL: `http://localhost:3000`

Health check: `http://localhost:3000/health`

## Available scripts

```bat
npm run build
npm run start
npm run start:dev
npm run start:prod
npm run lint
npm run lint:fix
npm test
npm run test:watch
npm run test:cov
npm run test:e2e
```

## Docker

Build image:

```bat
docker build -t devops-nestjs-app:local .
```

Run container:

```bat
docker run --rm -p 3000:3000 devops-nestjs-app:local
```

## GitHub Actions workflow

Workflow file: `.github/workflows/ci.yml`

On pull requests:

- Runs lint, build, unit tests, Docker build, and smoke test

On push to `main`:

- Runs all CI checks
- Pushes image to ECR (`sha` + `latest`)
- Triggers ECS rolling deployment

## Required GitHub repository variables

Create these in:
**GitHub -> Settings -> Secrets and variables -> Actions -> Variables**

- `AWS_REGION`
- `AWS_ROLE_ARN`
- `ECR_REPOSITORY`
- `ECS_CLUSTER`
- `ECS_SERVICE`

## AWS setup checklist (high-level)

1. Create ECR repository.
2. Create ECS cluster.
3. Create ECS task definition with container port `3000`.
4. Create ECS service (ALB recommended, health check path `/health`).
5. Configure IAM OIDC provider for GitHub Actions.
6. Create IAM role for GitHub Actions with ECR push + ECS update permissions.
7. Add GitHub variables listed above.
8. Push to `main` and verify workflow + ECS deployment.

For detailed step-by-step AWS Console instructions, see `docs/README.md`.

## Troubleshooting

- Lint says files are ignored: confirm `eslint.config.js` has a single `module.exports` and TS file globs.
- ECR push fails: verify `AWS_ROLE_ARN` permissions and `AWS_REGION`.
- ECS deploy fails: verify `ECS_CLUSTER`, `ECS_SERVICE`, task health checks, and network/security groups.

## License

UNLICENSED (learning project).
