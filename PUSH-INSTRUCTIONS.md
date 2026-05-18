# Pushing Drone-Installer-Package to GitHub

Step-by-step to get this repo on GitHub and trigger your first automated build.

## Prerequisites

- GitHub repo created: `https://github.com/JoeyBailey3/Drone-Installer-Package` ✓
- Git installed locally (Windows server or your Mac)
- Personal Access Token (or SSH keys) for pushing

## Step 1 — Extract the zip on your build machine

Download `drone-installer-package.zip` from this chat. Extract to a clean folder:

```powershell
# Windows
Expand-Archive drone-installer-package.zip -DestinationPath C:\repos\
cd C:\repos\drone-installer-package
```

Or on your Mac:
```bash
unzip drone-installer-package.zip -d ~/repos/
cd ~/repos/drone-installer-package
```

## Step 2 — Initialize git and connect to GitHub

```bash
git init
git branch -m main
git add .
git status
```

**Carefully review `git status` output.** You should see:
- ✓ All the documentation files
- ✓ The installer scripts and configs
- ✓ The code/ folder contents
- ✗ NO files in `installer/Bin/` except README.md (binaries are gitignored)
- ✗ NO `node_modules/` (gitignored)
- ✗ NO `*.log` files

If anything sensitive shows up, stop and check the `.gitignore`.

## Step 3 — First commit

```bash
git commit -m "Initial commit: Drone Server Installer build pipeline"
```

## Step 4 — Connect to GitHub and push

```bash
git remote add origin https://github.com/JoeyBailey3/Drone-Installer-Package.git
git push -u origin main
```

When prompted for credentials:
- **Username:** `JoeyBailey3`
- **Password:** Personal Access Token (NOT your GitHub password)

If you don't have a PAT yet, create one at https://github.com/settings/tokens with `repo` scope.

After push completes, refresh the repo on GitHub. All files should appear.

## Step 5 — Verify GitHub Actions workflow

1. Go to `https://github.com/JoeyBailey3/Drone-Installer-Package`
2. Click the **Actions** tab
3. You should see the "Build Installer" workflow listed
4. The workflow doesn't run automatically on the initial push (only on tags)

## Step 6 — Test the build with manual dispatch

Let's verify the workflow works WITHOUT creating a real release first:

1. GitHub → your repo → **Actions** tab
2. Click "Build Installer" workflow on the left sidebar
3. Click "**Run workflow**" button on the right
4. Branch: `main`
5. Click the green "Run workflow" button

A new workflow run appears. Click into it to watch progress.

Expected timeline:
- 0-1 min: Setup (checkout, environment)
- 1-3 min: Download binaries
- 3-4 min: Install Inno Setup
- 4-6 min: Compile installer
- 6-7 min: Upload artifact

Total: ~7 minutes for a full build.

## Step 7 — Download the test build

After the workflow succeeds (green checkmark):

1. Click into the completed workflow run
2. Scroll to the bottom — you'll see "Artifacts" section
3. Click on `DroneServer-Setup-dev-...` to download the .exe
4. Extract the downloaded zip to get the .exe

**This is a TEST build.** It doesn't create a GitHub Release because we didn't use a version tag.

## Step 8 — Test the .exe on a Windows VM

Before doing your first real release, test the installer:

1. Set up a Windows VM (Hyper-V, VMware, VirtualBox)
2. Install Node.js LTS on the VM
3. Copy the .exe to the VM
4. Run it as administrator
5. Click through the wizard
6. Verify it installs to `C:\DroneServer\`
7. Check that all files are there
8. Try starting services manually

If anything fails, fix it in your repo, commit, push, and re-trigger the build.

## Step 9 — Create your first real release

When you're confident the installer works:

```bash
git tag v1.0.0
git push origin v1.0.0
```

This triggers a build AND creates a GitHub Release with the .exe attached.

## Step 10 — Verify the release

After the build completes:

1. GitHub → your repo → **Releases** tab
2. You should see "Drone Server Installer v1.0.0"
3. Expand the assets — `DroneServer-Setup-v1.0.0.exe` should be downloadable
4. Click to download

This is your first releasable installer.

## Common issues

### "Permission denied" when pushing

PAT doesn't have `repo` scope, or the PAT has expired.

Fix: Create a new PAT at https://github.com/settings/tokens with `repo` scope. Update your git credentials.

### Workflow failed at "Download FFmpeg"

gyan.dev might have temporary issues. Re-run the workflow (top right of the workflow run page).

If consistently failing, update the FFmpeg URL in `.github/workflows/build-installer.yml`.

### Workflow failed at "Compile installer"

Read the error message. Usually one of:
- A file path in the .iss script doesn't match reality
- Inno Setup syntax error
- Missing source file

Fix locally, commit, push, re-run.

### Initial push rejected: "src refspec main does not match"

You haven't made any commits yet. Run:
```bash
git add .
git commit -m "Initial commit"
git push -u origin main
```

## What to do next

After your first successful release:

1. **Update your customer playbook** to reference the new download URL
2. **Tell your assistant** about the repo so they can pull releases
3. **Set up notification email** for build failures (GitHub Settings → Notifications)
4. **Plan v1.0.1** for any bug fixes you find during VM testing

## Going forward

Each time you want to release a new version:

```bash
# Make your changes
# Update CHANGELOG.md
# Commit
git add .
git commit -m "Description"

# Tag and push
git tag v1.0.1   # bump version
git push origin main
git push origin v1.0.1
```

GitHub Actions builds it automatically. You go to Releases and download.

That's the whole release process from now on. About 30 seconds of work to ship a new version.
