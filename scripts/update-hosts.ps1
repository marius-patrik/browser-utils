param(
  [ValidateSet("Install", "Remove", "Status", "RepairYouTube")]
  [string]$Action,

  [Parameter(Mandatory = $true)]
  [string]$BlocklistPath,

  [string]$ExtraDomains = "",

  [string]$LogPath = "",

  [switch]$NoPause
)

$ErrorActionPreference = "Stop"

$hostsPath = Join-Path $env:SystemRoot "System32\drivers\etc\hosts"
$begin = "# BEGIN VS CODE BROWSER ADBLOCK"
$end = "# END VS CODE BROWSER ADBLOCK"
$protectedDomainPatterns = @(
  '(^|\.)youtube\.com$',
  '(^|\.)youtube-nocookie\.com$',
  '^youtu\.be$',
  '(^|\.)googlevideo\.com$',
  '(^|\.)ytimg\.com$',
  '(^|\.)ggpht\.com$',
  '^youtubei\.googleapis\.com$',
  '^youtube\.googleapis\.com$'
)

function Write-Log {
  param([string]$Message)

  $line = "$(Get-Date -Format o) $Message"
  Write-Host $Message
  if ($LogPath) {
    Add-Content -LiteralPath $LogPath -Value $line -Encoding utf8
  }
}

function Test-IsAdmin {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = [Security.Principal.WindowsPrincipal]::new($identity)
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-ProtectedDomain {
  param([string]$Domain)

  $normalized = $Domain.Trim().ToLowerInvariant()
  foreach ($pattern in $protectedDomainPatterns) {
    if ($normalized -match $pattern) {
      return $true
    }
  }
  return $false
}

function Get-Domains {
  $domains = @()

  if (Test-Path -LiteralPath $BlocklistPath) {
    $domains += Get-Content -LiteralPath $BlocklistPath |
      ForEach-Object { $_.Trim() } |
      Where-Object { $_ -and -not $_.StartsWith("#") }
  }

  if ($ExtraDomains.Trim()) {
    $domains += $ExtraDomains.Split(",") |
      ForEach-Object { $_.Trim() } |
      Where-Object { $_ }
  }

  $blockedProtected = @()
  $safeDomains = @($domains |
    ForEach-Object { $_.ToLowerInvariant() } |
    Where-Object { $_ -match "^[a-z0-9.-]+$" -and $_ -notmatch "^\." } |
    Sort-Object -Unique |
    Where-Object {
      if (Test-ProtectedDomain $_) {
        $blockedProtected += $_
        return $false
      }
      return $true
    })

  if ($blockedProtected.Count) {
    Write-Log "Skipped YouTube playback-critical domains: $($blockedProtected -join ', ')"
  }

  $safeDomains
}

function Get-HostsDomainFromLine {
  param([string]$Line)

  if ($Line -match '^\s*(?:0\.0\.0\.0|127\.0\.0\.1|::1)\s+([^\s#]+)') {
    return $Matches[1].ToLowerInvariant()
  }
  return $null
}

try {
  $raw = if (Test-Path -LiteralPath $hostsPath) {
    Get-Content -LiteralPath $hostsPath -Raw
  } else {
    ""
  }

  $pattern = "(?ms)^$([regex]::Escape($begin))\r?\n.*?\r?\n$([regex]::Escape($end))\r?\n?"
  $clean = [regex]::Replace($raw, $pattern, "")
  $domains = @(Get-Domains)
  $installedEntries = @([regex]::Matches($raw, "(?m)^\s*(?:0\.0\.0\.0|127\.0\.0\.1|::1)\s+([^\s#]+)") | ForEach-Object { $_.Groups[1].Value })
  $unsafeYouTubeEntries = @($installedEntries | Where-Object { Test-ProtectedDomain $_ } | Sort-Object -Unique)
  $managedInstalled = $raw.Contains($begin) -and $raw.Contains($end)

  if ($Action -eq "Status") {
    Write-Log "Status: managedSection=$managedInstalled blocklistDomains=$($domains.Count) installedHostsEntries=$($installedEntries.Count) unsafeYouTubeHosts=$($unsafeYouTubeEntries.Count) hostsPath=$hostsPath"
    if ($unsafeYouTubeEntries.Count) {
      Write-Log "Unsafe YouTube hosts entries: $($unsafeYouTubeEntries -join ', ')"
    }
    exit 0
  }

  if (-not (Test-IsAdmin)) {
    throw "Administrator rights are required to edit $hostsPath. Re-run from the VS Code command and approve the UAC prompt."
  }

  if ($Action -eq "RepairYouTube") {
    $lines = @()
    $removed = @()

    if (Test-Path -LiteralPath $hostsPath) {
      foreach ($line in Get-Content -LiteralPath $hostsPath) {
        $domain = Get-HostsDomainFromLine $line
        if ($domain -and (Test-ProtectedDomain $domain)) {
          $removed += $domain
          continue
        }
        $lines += $line
      }
    }

    Set-Content -LiteralPath $hostsPath -Value ($lines -join [Environment]::NewLine) -Encoding ascii
    ipconfig /flushdns | Out-Null
    Write-Log "Removed YouTube playback-critical hosts entries: $($removed.Count)"
    if ($removed.Count) {
      Write-Log "Removed entries: $((@($removed) | Sort-Object -Unique) -join ', ')"
    }
    Write-Log "Restart VS Code before retesting YouTube playback."
  } elseif ($Action -eq "Install") {
    if (-not $domains.Count) {
      throw "No domains found to block."
    }

    $entries = foreach ($domain in $domains) {
      "0.0.0.0 $domain"
    }

    $section = @(
      $begin
      "# Managed by VSC Utils"
      "# Updated $(Get-Date -Format o)"
      $entries
      $end
    ) -join [Environment]::NewLine

    $next = $clean.TrimEnd() + [Environment]::NewLine + [Environment]::NewLine + $section + [Environment]::NewLine
    Set-Content -LiteralPath $hostsPath -Value $next -Encoding ascii
    ipconfig /flushdns | Out-Null
    Write-Log "Installed VSC Utils hosts entries: $($domains.Count)"
    Write-Log "Restart VS Code before retesting the integrated browser."
  } else {
    Set-Content -LiteralPath $hostsPath -Value ($clean.TrimEnd() + [Environment]::NewLine) -Encoding ascii
    ipconfig /flushdns | Out-Null
    Write-Log "Removed VSC Utils hosts entries."
    Write-Log "Restart VS Code before retesting the integrated browser."
  }
} catch {
  Write-Log "ERROR: $($_.Exception.Message)"
  throw
}

if (-not $NoPause) {
  Read-Host "Press Enter to close"
}
