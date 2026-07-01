param(
  [ValidateSet("Install", "Remove", "Status")]
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

  $domains |
    ForEach-Object { $_.ToLowerInvariant() } |
    Where-Object { $_ -match "^[a-z0-9.-]+$" -and $_ -notmatch "^\." } |
    Sort-Object -Unique
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
  $installedEntries = @([regex]::Matches($raw, "(?m)^0\.0\.0\.0\s+(.+)$") | ForEach-Object { $_.Groups[1].Value })
  $managedInstalled = $raw.Contains($begin) -and $raw.Contains($end)

  if ($Action -eq "Status") {
    Write-Log "Status: managedSection=$managedInstalled blocklistDomains=$($domains.Count) installedHostsEntries=$($installedEntries.Count) hostsPath=$hostsPath"
    exit 0
  }

  if (-not (Test-IsAdmin)) {
    throw "Administrator rights are required to edit $hostsPath. Re-run from the VS Code command and approve the UAC prompt."
  }

  if ($Action -eq "Install") {
    if (-not $domains.Count) {
      throw "No domains found to block."
    }

    $entries = foreach ($domain in $domains) {
      "0.0.0.0 $domain"
    }

    $section = @(
      $begin
      "# Managed by patrik-local.vscode-browser-adblock"
      "# Updated $(Get-Date -Format o)"
      $entries
      $end
    ) -join [Environment]::NewLine

    $next = $clean.TrimEnd() + [Environment]::NewLine + [Environment]::NewLine + $section + [Environment]::NewLine
    Set-Content -LiteralPath $hostsPath -Value $next -Encoding ascii
    ipconfig /flushdns | Out-Null
    Write-Log "Installed VS Code Browser Adblock hosts entries: $($domains.Count)"
    Write-Log "Restart VS Code before retesting the integrated browser."
  } else {
    Set-Content -LiteralPath $hostsPath -Value ($clean.TrimEnd() + [Environment]::NewLine) -Encoding ascii
    ipconfig /flushdns | Out-Null
    Write-Log "Removed VS Code Browser Adblock hosts entries."
    Write-Log "Restart VS Code before retesting the integrated browser."
  }
} catch {
  Write-Log "ERROR: $($_.Exception.Message)"
  throw
}

if (-not $NoPause) {
  Read-Host "Press Enter to close"
}
