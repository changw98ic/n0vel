#!/usr/bin/env node
// Local proxy: accepts Claude model names, rewrites to kimi-k2.6, forwards to ollama.
// Usage: node kimi-proxy.mjs [port]
// Default port: 4455

import http from "node:http";
import https from "node:https";

const PORT = parseInt(process.argv[2] || "4455", 10);
const TARGET = "https://ollama.com";

function proxy(req, res) {
  const chunks = [];
  req.on("data", (c) => chunks.push(c));
  req.on("end", () => {
    let body = Buffer.concat(chunks).toString();

    // Rewrite model field: any Claude model name → kimi-k2.6
    if (body) {
      body = body.replace(
        /"model"\s*:\s*"[^"]*"/g,
        `"model":"kimi-k2.6"`
      );
    }

    const url = new URL(req.url, TARGET);
    const opts = {
      hostname: url.hostname,
      port: 443,
      path: url.pathname + url.search,
      method: req.method,
      headers: {
        ...req.headers,
        host: url.hostname,
        "content-length": Buffer.byteLength(body),
      },
    };

    const upstream = https.request(opts, (upRes) => {
      res.writeHead(upRes.statusCode, upRes.headers);
      upRes.pipe(res);
    });

    upstream.on("error", (e) => {
      console.error(`proxy error: ${e.message}`);
      res.writeHead(502);
      res.end(`proxy error: ${e.message}`);
    });

    upstream.end(body);
  });
}

http.createServer(proxy).listen(PORT, "127.0.0.1", () => {
  console.log(`kimi-proxy listening on http://127.0.0.1:${PORT}`);
});
