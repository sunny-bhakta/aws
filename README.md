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
