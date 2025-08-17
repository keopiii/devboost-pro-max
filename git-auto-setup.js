#!/usr/bin/env node
/**
 * USAGE (from your project folder):
 *   node git-auto-setup.js --repo devboost-pro-max --user keopiii --email keopiii.kanji@gmail.com --visibility public --transport auto --init yes --token YOUR_GITHUB_PAT
 *
 * Notes:
 * - If --token is provided, the script will create the GitHub repo via API and (if SSH) attempt to add your SSH public key.
 * - If SSH key doesn't exist, it will generate one (ed25519) without passphrase.
 */

const { execSync } = require("child_process");
const fs = require("fs");
const os = require("os");
const path = require("path");
const https = require("https");

function sh(cmd, opts = {}) {
  return execSync(cmd, { stdio: "pipe", encoding: "utf8", ...opts }).trim();
}

function postGitHub(urlPath, token, bodyObj) {
  const body = JSON.stringify(bodyObj);
  const options = {
    hostname: "api.github.com",
    path: urlPath,
    method: "POST",
    headers: {
      "User-Agent": "git-auto-setup",
      "Content-Type": "application/json",
      "Content-Length": Buffer.byteLength(body),
      Authorization: `token ${token}`,
    },
  };
  return new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      let data = "";
      res.on("data", (d) => (data += d));
      res.on("end", () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          resolve(JSON.parse(data || "{}"));
        } else {
          reject(new Error(`GitHub API ${res.statusCode}: ${data}`));
        }
      });
    });
    req.on("error", reject);
    req.write(body);
    req.end();
  });
}

function writeUtf8NoBom(file, content) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, content, { encoding: "utf8", flag: "w" });
}

// Parse args (simple)
const args = process.argv.slice(2);
function getArg(name, def = "") {
  const i = args.findIndex((a) => a === `--${name}`);
  return i >= 0 && args[i + 1] ? args[i + 1] : def;
}

const repo = getArg("repo", "devboost-pro-max");
const user = getArg("user", "keopiii");
const email = getArg("email", "keopiii.kanji@gmail.com");
const visibility = getArg("visibility", "public"); // public|private
const transport = getArg("transport", "auto"); // auto|yes|no (yes=SSH, no=HTTPS)
const token = getArg("token", ""); // GitHub PAT (optional but needed for auto-create repo)
const initFiles = (getArg("init", "yes").toLowerCase() !== "no");
const cwd = process.cwd();

// Check git
try { sh("git --version"); } catch { console.error("git not found in PATH"); process.exit(1); }

// Set global identity if missing
try { 
  const name = sh("git config --global user.name || echo");
  if (!name) sh(`git config --global user.name "${user}"`);
  const em = sh("git config --global user.email || echo");
  if (!em) sh(`git config --global user.email "${email}"`);
} catch {}

if (!fs.existsSync(path.join(cwd, ".git"))) {
  sh("git init");
}

if (initFiles) {
  const year = new Date().getFullYear();
  const readme = `# ${repo}\n\nCreated by automated setup.`;
  const gitignore = [
    "node_modules/",
    "dist/",
    "build/",
    ".vscode/",
    ".DS_Store",
    "*.log",
  ].join("\n");
  const license = `MIT License

Copyright (c) ${year} ${user}

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
`;
  if (!fs.existsSync(path.join(cwd, "README.md"))) writeUtf8NoBom(path.join(cwd,"README.md"), readme);
  if (!fs.existsSync(path.join(cwd, ".gitignore"))) writeUtf8NoBom(path.join(cwd,".gitignore"), gitignore);
  if (!fs.existsSync(path.join(cwd, "LICENSE"))) writeUtf8NoBom(path.join(cwd,"LICENSE"), license);
}

// SSH detect/generate
let useSSH = false;
if (transport === "yes" || transport === "auto") {
  const sshDir = path.join(os.homedir(), ".ssh");
  const key = path.join(sshDir, "id_ed25519");
  const pub = key + ".pub";
  if (!fs.existsSync(pub)) {
    fs.mkdirSync(sshDir, { recursive: true });
    try { sh(`ssh-keygen -t ed25519 -C "${email}" -N "" -f "${key}"`); } catch {}
  }
  useSSH = fs.existsSync(pub);
  if (useSSH) {
    try { sh(`ssh-add "${key}"`); } catch {}
  }
}

// Create GitHub repo via API if token provided
if (token) {
  const createBody = { name: repo, private: (visibility === "private"), auto_init: false };
  postGitHub("/user/repos", token, createBody)
    .catch(e => console.warn("Repo API create warning:", e.message));
  if (useSSH) {
    const pubKey = fs.readFileSync(path.join(os.homedir(), ".ssh", "id_ed25519.pub"), "utf8");
    const keyBody = { title: `auto-key-${os.hostname()}`, key: pubKey.trim() };
    postGitHub("/user/keys", token, keyBody)
      .catch(e => console.warn("SSH key API add warning:", e.message));
  }
}

// Set remote
let remotes = "";
try { remotes = sh("git remote"); } catch {}
if (!remotes.includes("origin")) {
  if (useSSH) {
    sh(`git remote add origin git@github.com:${user}/${repo}.git`);
  } else {
    sh(`git remote add origin https://github.com/${user}/${repo}.git`);
  }
} else {
  if (useSSH) {
    sh(`git remote set-url origin git@github.com:${user}/${repo}.git`);
  } else {
    sh(`git remote set-url origin https://github.com/${user}/${repo}.git`);
  }
}

// commit + push
try { sh("git add -A"); } catch {}
try { sh(`git commit -m "Initial commit"`); } catch {}
try { sh("git branch -M main"); } catch {}

try {
  console.log("Pushing to GitHub...");
  sh("git push -u origin main", { stdio: "inherit" });
  console.log(`Done. Repo: https://github.com/${user}/${repo}`);
} catch (e) {
  console.warn("Push failed. If using HTTPS, Git may prompt for login. If using SSH, ensure the key is added on GitHub.");
  console.warn(e.message);
  process.exit(0);
}
