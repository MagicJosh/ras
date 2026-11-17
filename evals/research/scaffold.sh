#!/bin/sh
# A small Express 4 app that uses two calls Express 5 removed, with the version pinned in a lockfile.
set -eu
cat > package.json <<'JSON'
{
  "name": "notes-api",
  "version": "1.0.0",
  "private": true,
  "dependencies": { "express": "^4.18.2" }
}
JSON
cat > package-lock.json <<'JSON'
{
  "name": "notes-api",
  "version": "1.0.0",
  "lockfileVersion": 3,
  "requires": true,
  "packages": {
    "": { "name": "notes-api", "version": "1.0.0", "dependencies": { "express": "^4.18.2" } },
    "node_modules/express": {
      "version": "4.18.2",
      "resolved": "https://registry.npmjs.org/express/-/express-4.18.2.tgz"
    }
  }
}
JSON
cat > server.js <<'JS'
const express = require('express');
const app = express();
const notes = new Map();

app.get('/notes/:id', (req, res) => {
  const id = req.param('id');
  res.json(notes.get(id) || null);
});

app.del('/notes/:id', (req, res) => {
  notes.delete(req.params.id);
  res.sendStatus(204);
});

app.listen(3000);
JS
git init -q
git add -A
git -c user.name=eval -c user.email=eval@example.com commit -qm init
