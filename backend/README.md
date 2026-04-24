# OPTIMUM Backend

## Setup

1. Create a new MongoDB Atlas user/password and set `MONGODB_URI` locally (do not commit secrets).
2. Set admin credentials:

- `ADMIN_USER`
- `ADMIN_PASS`

## Local dev

```bash
npm i
npm run offline
```

## Deploy

```bash
npm run deploy
```

After deployment, Serverless prints an `httpApi` URL. Use it in `admin.html` as the API Base URL.
