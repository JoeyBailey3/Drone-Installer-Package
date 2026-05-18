# Release Process

How to ship a new version of the installer to customers.

## Versioning

We use semantic versioning: `MAJOR.MINOR.PATCH`

- **PATCH** (1.0.x) — bug fixes, no new features, fully backward compatible
- **MINOR** (1.x.0) — new features, no breaking changes
- **MAJOR** (x.0.0) — breaking changes, customers may need to take action

Examples:
- `1.0.1` — fixed firewall rule bug
- `1.1.0` — added telemetry endpoint
- `2.0.0` — switched from ADB to Cloud API (breaking change)

Use lowercase `v` prefix for tags: `v1.0.0`, `v1.1.0`, etc.

## Standard release workflow

### 1. Make your changes locally

Pull latest:
```powershell
git pull origin main
```

Make your changes to:
- `installer/Code/drone-api/server.js` — API endpoints
- `installer/Code/ws-broadcaster/ws-broadcaster.js` — video broadcaster
- `installer/Scripts/*.ps1` — install scripts
- `installer/Configs/*.template` — config templates
- `installer/InnoSetup/DroneServerSetup.iss` — installer behavior
- `docs/customer/*.md` — customer-facing docs

### 2. Test locally if you have a Windows machine

If you have Inno Setup installed locally:
```powershell
cd installer/InnoSetup
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" DroneServerSetup.iss
```

Output goes to `installer/InnoSetup/Output/`. Test on a VM.

If you don't have Windows, skip this — the GitHub Actions build will handle it.

### 3. Update the CHANGELOG

Open `CHANGELOG.md`, add an entry for the new version:

```markdown
## [1.1.0] - 2026-05-22

### Added
- /drone/telemetry endpoint returns real battery and GPS data

### Changed
- Default video resolution from 928x580 to 800x500 for better mobile performance

### Fixed
- WebSocket broadcaster crashing when no clients connected for >5 minutes
- Firewall rules not being applied if PowerShell execution policy was restrictive

### Known Issues
- Software RTH still requires manual hardware button
```

### 4. Commit and push

```powershell
git add .
git commit -m "Release v1.1.0: telemetry endpoint, performance improvements"
git push origin main
```

### 5. Create and push the version tag

```powershell
git tag v1.1.0
git push origin v1.1.0
```

**Pushing the tag is what triggers the GitHub Actions build.**

### 6. Watch the build

Go to your repo on GitHub:
- Click the **Actions** tab
- Find the running workflow for "Build Installer"
- Watch the progress (takes about 5-7 minutes)

Each step shows logs. If a step fails, read the log to understand why.

### 7. Verify the release

If the workflow succeeds:
- Click the **Releases** tab on your repo
- You'll see "Drone Server Installer v1.1.0" with the `.exe` attached
- Download the `.exe` and test on a VM before distributing to customers

### 8. Distribute to customers

For each customer who wants the update:
- Send them the `.exe` (email link to the GitHub Release, encrypted file share, etc.)
- Or send your tech a link to grab the latest from GitHub Releases

The installer handles upgrades automatically (overwrites existing files, preserves config.json since it's marked `onlyifdoesntexist`).

## Manual builds without a release

Sometimes you want to test a build without creating a release. Use manual dispatch:

1. GitHub → your repo → Actions tab
2. Click "Build Installer" workflow on the left
3. Click the "Run workflow" button on the right
4. Choose branch (usually `main`)
5. Click green "Run workflow" button

This builds the installer but creates an **artifact** (downloadable from the workflow run page) instead of a Release. Useful for testing.

Artifacts expire after 30 days.

## Hotfix workflow (urgent bug fix)

Sometimes you discover a critical bug in production. Skip the normal flow:

1. Create a hotfix branch:
```powershell
git checkout -b hotfix-v1.0.1
```

2. Fix the bug, test if possible

3. Update CHANGELOG with the fix

4. Tag and push:
```powershell
git add .
git commit -m "Hotfix v1.0.1: critical firewall bug"
git tag v1.0.1
git push origin hotfix-v1.0.1
git push origin v1.0.1
```

5. Build runs automatically

6. Merge hotfix back to main when stable:
```powershell
git checkout main
git merge hotfix-v1.0.1
git push origin main
```

## What to do when a build fails

GitHub Actions shows red ❌ next to the failed step. Common failures:

### "Download FFmpeg failed"
- gyan.dev had a temporary outage, or moved a URL
- Re-run the workflow (sometimes a transient issue)
- If persistent, update the URL in `.github/workflows/build-installer.yml`

### "Inno Setup compile failed"
- Usually means a referenced file is missing
- Read the compile output for "file not found" messages
- Add the missing file to the repo, commit, retag

### "Permission denied" creating release
- Workflow has `permissions: contents: write` set
- If failing, check repo Settings → Actions → General → Workflow permissions

### Build takes too long / hangs
- Default timeout is 30 minutes
- If consistently slow, check if downloads are timing out
- Consider caching dependencies (advanced optimization)

## Distributing to customers (private repo)

Since the repo is private, customers can't directly access GitHub Releases.

**Option 1 — Download yourself, share with customers**

For each release:
1. Go to GitHub Releases
2. Download the `.exe`
3. Upload to your customer distribution method:
   - Email attachment (if file <25MB — probably not given installer size)
   - OneDrive / Google Drive shared link
   - Customer's network share
   - USB drive (for on-site installs)

**Option 2 — Invite customer/tech as collaborator**

For specific customers/techs who do their own installs:
1. Repo Settings → Collaborators → Add
2. Send invitation
3. They access Releases directly

**Option 3 — Per-customer fork**

For paid customers with custom builds:
1. Create a private fork of the repo
2. Apply customer-specific modifications
3. Build custom installer
4. Send to that customer

For most cases, Option 1 is simplest.

## Tracking what each customer has

Keep a spreadsheet (or simple text file) tracking:

| Customer | Install Date | Installer Version | Server IP | Notes |
|---|---|---|---|---|
| Test Site Alpha | 2026-04-15 | v1.0.0 | 10.0.40.10 | First test install |
| Customer X | 2026-05-01 | v1.0.0 | 192.168.1.50 | Production |
| Customer Y | 2026-05-22 | v1.1.0 | 10.0.0.5 | Got telemetry update |

When you ship v1.2.0, you know who's on older versions and may want to upgrade.

## Rolling back a release

If v1.1.0 has a critical bug:

1. **Don't delete the bad release** — keep it visible so people know what to avoid
2. **Mark it as pre-release or deprecated** on the GitHub Release page
3. **Tag a fix version** quickly (v1.1.1)
4. **Tell affected customers** to upgrade to v1.1.1

If customers have already installed v1.1.0:
- Test if installing v1.1.1 over v1.1.0 fixes it
- If not, document a manual rollback procedure
- For severe issues, send a hand-crafted hotfix script

## Cost monitoring

GitHub Actions has free tier limits:
- 2,000 minutes/month for private repos
- Free for public repos

Each build uses ~5 minutes. You can do ~400 builds/month free.

To check usage:
- GitHub → your account → Settings → Billing & plans → Plans & usage

If you exceed, builds queue up until next month or you can pay for more minutes ($0.008/min for Windows).

## Future improvements

When you've got the basics working:

1. **Automated testing** — workflow runs tests before building
2. **Multiple architectures** — installers for Windows x64, ARM64, etc.
3. **Code signing** — buy a certificate, sign the .exe in the workflow
4. **Update notifications** — installer checks for newer versions on startup
5. **Telemetry** — track installer success/failure rates across customers
6. **Beta channel** — separate stable vs. beta releases

Each is a separate project but valuable as you scale.
