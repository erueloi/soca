param (
    [Parameter(Mandatory = $false)]
    [string]$Version,
    
    [Parameter(Mandatory = $false)]
    [string]$ReleaseNotes
)

$ErrorActionPreference = "Stop"

# Setup UTF-8 Output for better icon support in some terminals
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Write-Step {
    param([string]$Message)
    Write-Host "`n--- $Message ---" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-ErrorMsg {
    param([string]$Message)
    Write-Host "❌ Error: $Message" -ForegroundColor Red
}

try {
    # --- Step 0: Check Version Argument ---
    if (-not $Version) {
        Write-ErrorMsg "Version number is required. Usage: .\deploy.ps1 -Version '1.1.0'"
        exit 1
    }

    Write-Host "🚀 Starting deployment for Soca v$Version..." -ForegroundColor Magenta

    # --- Step 1: Update pubspec.yaml ---
    Write-Step "Step 1: Updating pubspec.yaml"
    $pubspecPath = "pubspec.yaml"
    if (-not (Test-Path $pubspecPath)) { throw "pubspec.yaml not found!" }
    
    $content = Get-Content $pubspecPath -Raw
    # Regex replacement for version: 1.0.0+1 etc.
    if ($content -match "(?m)^version: .*") {
        $newContent = $content -replace "(?m)^version: .*", "version: $Version"
        Set-Content -Path $pubspecPath -Value $newContent -Encoding UTF8
        Write-Success "Updated version to $Version"
    }
    else {
        Write-ErrorMsg "Could not find 'version:' in pubspec.yaml"
    }

    # --- Step 2: Update Release Notes (Optional) ---
    if ($ReleaseNotes) {
        Write-Step "Step 2: Updating Release Notes"
        $notesPath = "assets/release_notes.md"
        if (Test-Path $notesPath) {
            $currentNotes = Get-Content $notesPath -Raw
            
            # Formatting: Replace ". " with ".\n" for line breaks
            $formattedNotes = $ReleaseNotes -replace "\. ", ".`n"
            
            $header = "# Release Notes`n`n## v$Version`n$formattedNotes`n"
            $newNotes = $header + ($currentNotes -replace "# Release Notes\s+", "")
            Set-Content -Path $notesPath -Value $newNotes -Encoding UTF8
            Write-Success "Added notes to assets/release_notes.md"
        }
    }

    # --- Step 3: Flutter Clean & Get ---
    Write-Step "Step 3: Cleaning & Fetching Dependencies"
    cmd /c "flutter clean"
    cmd /c "flutter pub get"
    Write-Success "Dependencies up to date."

    # --- Step 4: Build Android APK ---
    Write-Step "Step 4: Building Android APK"
    cmd /c "flutter build apk --release --no-tree-shake-icons"
    if ($LASTEXITCODE -ne 0) { throw "Android build failed" }
    Write-Success "APK Built."

    # --- Step 5: Copy APK for Web ---
    # Moved to after Web Build logic effectively, but we prepare variable here or wait.
    # Actually, proceed to build web first.

    # --- Step 6: Build Web ---
    Write-Step "Step 6: Building Web PWA"
    cmd /c "flutter build web --release --no-tree-shake-icons"
    if ($LASTEXITCODE -ne 0) { throw "Web build failed" }
    Write-Success "Web Built."
    
    # Copy APK
    $apkSource = "build\app\outputs\flutter-apk\app-release.apk"
    $apkDest = "build\web\soca.apk"
    Copy-Item -Path $apkSource -Destination $apkDest -Force
    Write-Success "APK copied to $apkDest"

    # Generate version.json
    $versionJson = @{
        version = $Version
        apkUrl = "https://soca-aacac.web.app/soca.apk"
    } | ConvertTo-Json
    
    Set-Content -Path "build/web/version.json" -Value $versionJson -Encoding UTF8
    Write-Success "Generated version.json"

    # --- Step 7: Deploy to Firebase ---
    Write-Step "Step 7: Deploying to Firebase Hosting & Functions"
    
    # Deploy functions first (or together)
    # Using --only functions,hosting
    cmd /c "firebase deploy --only functions,hosting"
    
    if ($LASTEXITCODE -ne 0) { throw "Firebase deploy failed" }
    Write-Success "Deployed Functions and Hosting"

    # --- Step 8: Git & Tagging ---
    Write-Step "Step 8: Git & Tagging"
    $tagName = "v$Version"
    
    # Check for uncommitted changes (like pubspec or release_notes)
    $gitStatus = git status --porcelain
    if ($gitStatus) {
        git add .
        
        $commitMsg = "Bump version to $Version"
        if ($ReleaseNotes) {
            # Using ReleaseNotes text for the commit message as requested
            $commitMsg = "Release v$Version`n`n$ReleaseNotes"
        }

        git commit -m $commitMsg
        Write-Success "Committed changes."
    }

    $tagExists = git tag -l $tagName
    if (-not $tagExists) {
        git tag -a $tagName -m "Release $Version"
        Write-Success "Created Git Tag: $tagName"
    }
    else {
        Write-Host "Tag $tagName already exists." -ForegroundColor Yellow
    }

    # --- Step 9: Push to Remote ---
    Write-Step "Step 9: Pushing to Remote"
    # Pushing current branch and tags
    git push origin HEAD
    if ($LASTEXITCODE -ne 0) { Write-ErrorMsg "git push failed (maybe no upstream?)" }
    
    git push origin --tags
    if ($LASTEXITCODE -ne 0) { Write-ErrorMsg "git push --tags failed" }
    
    Write-Success "Pushed to origin."

    Write-Host "`n🎉 Deployment Complete! Visit https://soca-aacac.web.app" -ForegroundColor Green
    
}
catch {
    Write-ErrorMsg $_.Exception.Message
    exit 1
}
