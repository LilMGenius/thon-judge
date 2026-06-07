param(
  [Parameter(Position = 0)]
  [string]$Command,
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Rest
)

$ErrorActionPreference = "Stop"

function Fail {
  param([string]$Message, [int]$Code = 2)
  [Console]::Error.WriteLine("validation error: $Message")
  exit $Code
}

function Get-ArgsMap {
  param([string[]]$Items)
  $map = @{}
  for ($i = 0; $i -lt $Items.Count; $i++) {
    $item = $Items[$i]
    if (-not $item.StartsWith("--")) {
      continue
    }
    $key = $item.Substring(2)
    if ($i + 1 -ge $Items.Count -or $Items[$i + 1].StartsWith("--")) {
      $map[$key] = $true
    } else {
      $map[$key] = $Items[$i + 1]
      $i++
    }
  }
  return $map
}

function Require-Arg {
  param($Map, [string]$Name)
  if (-not $Map.ContainsKey($Name) -or [string]::IsNullOrWhiteSpace([string]$Map[$Name])) {
    Fail "missing --$Name"
  }
  return [string]$Map[$Name]
}

function Normalize-Path {
  param([string]$PathValue)
  return [System.IO.Path]::GetFullPath($PathValue)
}

function Get-LobsterInfo {
  param($Record)
  $explicit = 0
  if ($null -ne $Record.lobster_count) {
    $explicit = [int]$Record.lobster_count
  }
  $events = @()
  if ($null -ne $Record.lobsters) {
    $events = @($Record.lobsters)
  }
  $count = [Math]::Max($explicit, $events.Count)
  $warnings = @()
  if ($explicit -gt 0 -and $events.Count -gt 0 -and $explicit -ne $events.Count) {
    $warnings += "lobster_count disagrees with lobsters length; using higher count"
  }
  return [pscustomobject]@{ count = $count; warnings = $warnings }
}

function ConvertTo-Submission {
  param($Record, [string]$Source)
  $name = [string]$Record.name
  $repo = [string]$Record.repo_url
  if ([string]::IsNullOrWhiteSpace($repo)) {
    $repo = [string]$Record.repo
  }
  if ([string]::IsNullOrWhiteSpace($name)) {
    Fail "$Source name is required"
  }
  if ([string]::IsNullOrWhiteSpace($repo)) {
    Fail "$Source gitRemoteUrl is required"
  }
  $screenshots = @()
  if ($null -ne $Record.screenshots) {
    if ($Record.screenshots -is [string]) {
      $screenshots = @($Record.screenshots.Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    } else {
      $screenshots = @($Record.screenshots)
    }
  }
  $lobster = Get-LobsterInfo $Record
  return [pscustomobject]@{
    name = $name
    repo_url = $repo
    screenshots = $screenshots
    lobster_count = $lobster.count
    warnings = $lobster.warnings
  }
}

function Read-LabeledSubmissions {
  param([string]$Path)
  $records = New-Object System.Collections.Generic.List[object]
  $current = $null
  $lines = Get-Content $Path
  for ($i = 0; $i -lt $lines.Count; $i++) {
    $lineNumber = $i + 1
    $line = $lines[$i].Trim()
    if (-not $line) { continue }
    if ($line.StartsWith("## ")) {
      if ($null -ne $current) { $records.Add([pscustomobject]$current) }
      $current = @{ name = $line.Substring(3).Trim() }
      continue
    }
    if ($line -notmatch ":") {
      Fail "$(Split-Path -Leaf $Path) line $lineNumber expected Label: value"
    }
    if ($null -eq $current) {
      Fail "$(Split-Path -Leaf $Path) line $lineNumber submission heading required"
    }
    $parts = $line.Split(":", 2)
    $key = $parts[0].Trim().ToLowerInvariant().Replace(" ", "_")
    $value = $parts[1].Trim()
    switch ($key) {
      { $_ -in @("repo", "repo_url", "git_remote_url") } { $current["repo_url"] = $value; break }
      "screenshots" { $current["screenshots"] = @($value.Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ }); break }
      "lobster_count" { $current["lobster_count"] = [int]$value; break }
      "lobsters" { $current["lobsters"] = @($value.Split(",") | ForEach-Object { [pscustomobject]@{ marker = "(lobster)"; index = [int](([string]$_).Trim()) } }); break }
      default { $current[$key] = $value }
    }
  }
  if ($null -ne $current) { $records.Add([pscustomobject]$current) }
  return $records.ToArray()
}

function Read-Submissions {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    Fail "$Path not found"
  }
  $ext = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
  if ($ext -eq ".json") {
    $payload = Get-Content $Path -Raw | ConvertFrom-Json
    if ($null -ne $payload.submissions) {
      $records = @($payload.submissions)
    } elseif ($payload -is [array]) {
      $records = @($payload)
    } else {
      $records = @()
    }
  } elseif ($ext -in @(".md", ".txt")) {
    $records = Read-LabeledSubmissions $Path
  } else {
    Fail "unsupported input format $Path"
  }
  if ($records.Count -eq 0) {
    Fail "$Path must contain at least one submission"
  }
  return @($records | ForEach-Object { ConvertTo-Submission $_ $Path })
}

function Get-Criteria {
  param([string]$Path)
  $text = Get-Content $Path -Raw
  $weights = [ordered]@{}
  foreach ($name in @("Product", "Creativity", "Harness", "Lobster")) {
    $match = [regex]::Match($text, "\|\s*$name\s*\|\s*(\d+)\s*\|")
    if (-not $match.Success) {
      Fail "criteria weight missing: $name"
    }
    $weights[$name.ToLowerInvariant()] = [int]$match.Groups[1].Value
  }
  return $weights
}

function Get-HarnessSignals {
  param([string]$Cases)
  if (-not (Test-Path -LiteralPath $Cases)) {
    Fail "cases directory not found"
  }
  $required = @("polysona-harness-case-study.md", "win-hooks-harness-case-study.md")
  foreach ($file in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $Cases $file))) {
      Fail "missing harness case study: $file"
    }
  }
  $rows = @(
    @("predicate", "Predicate criteria", "win-hooks-harness-case-study.md"),
    @("falsifiable", "Falsifiability", "win-hooks-harness-case-study.md"),
    @("reproducible", "Reproducibility", "win-hooks-harness-case-study.md"),
    @("side-effects", "Side-effect awareness", "win-hooks-harness-case-study.md"),
    @("root-cause", "Root-cause discipline", "win-hooks-harness-case-study.md"),
    @("verification-ladder", "Verification ladder", "win-hooks-harness-case-study.md"),
    @("clean-state", "Clean-state causality", "win-hooks-harness-case-study.md"),
    @("autonomy", "Hands-off autonomy", "polysona-harness-case-study.md"),
    @("control-surface", "Control surfaces", "polysona-harness-case-study.md"),
    @("drift", "Drift prevention", "polysona-harness-case-study.md"),
    @("budget", "Cost-aware QA", "polysona-harness-case-study.md"),
    @("durable-state", "Durable state", "polysona-harness-case-study.md")
  )
  return @($rows | ForEach-Object {
    [pscustomobject]@{
      id = $_[0]
      label = $_[1]
      source_case = $_[2]
      positive_evidence_patterns = @($_[0], $_[1])
    }
  })
}

function Get-OwnerRepo {
  param([string]$RepoUrl)
  $match = [regex]::Match($RepoUrl, "github\.com[:/]([^/]+)/([^/.]+)")
  if ($match.Success) {
    return "$($match.Groups[1].Value)/$($match.Groups[2].Value)"
  }
  return ($RepoUrl.TrimEnd("/") -split "/")[-1]
}

function Get-GithubEvidence {
  param([string]$RepoUrl, [string]$FixtureDir)
  $ownerRepo = Get-OwnerRepo $RepoUrl
  if ($FixtureDir) {
    $fixture = Join-Path $FixtureDir (($ownerRepo -replace "/", "__") + ".json")
    if (-not (Test-Path -LiteralPath $fixture)) {
      return [pscustomobject]@{ readme_text = ""; commits = @(); warnings = @("GitHub fixture not found for $ownerRepo") }
    }
    return Get-Content $fixture -Raw | ConvertFrom-Json
  }
  return [pscustomobject]@{ readme_text = ""; commits = @(); warnings = @("live GitHub collection not configured in this run") }
}

function Get-Score {
  param($Submission, $Github)
  $warnings = @($Submission.warnings) + @($Github.warnings)
  $readme = [string]$Github.readme_text
  if (-not $readme) { $warnings += "README evidence missing" }
  $commits = @($Github.commits)
  if ($commits.Count -eq 0) { $warnings += "commit evidence missing" }
  $text = $readme.ToLowerInvariant()
  $product = if ($text.Contains("product") -or $text.Contains("workflow")) { 32 } elseif ($readme) { 12 } else { 5 }
  $creativity = if ($text.Contains("original") -or $text.Contains("niche")) { 18 } elseif ($readme) { 14 } else { 5 }
  $harnessCount = 0
  foreach ($word in @("harness", "reproducible", "evidence", "deterministic", "verification")) {
    if ($text.Contains($word)) { $harnessCount++ }
  }
  $harness = if ($harnessCount -ge 3) { 25 } elseif ($readme) { 10 } else { 5 }
  $lobster = [Math]::Max(0, 20 - 4 * [int]$Submission.lobster_count)
  $categories = [ordered]@{
    product = [pscustomobject]@{ points = $product; rationale = "Product evidence from README" }
    creativity = [pscustomobject]@{ points = $creativity; rationale = "Originality evidence from README" }
    harness = [pscustomobject]@{ points = $harness; rationale = "Harness evidence from README and case studies" }
    lobster = [pscustomobject]@{ points = $lobster; rationale = "Lobster penalty for $($Submission.lobster_count) uses" }
  }
  return [pscustomobject]@{
    name = $Submission.name
    repo_url = $Submission.repo_url
    total = $product + $creativity + $harness + $lobster
    categories = $categories
    warnings = $warnings
    screenshots = @($Submission.screenshots)
    rationale = @($categories.product.rationale, $categories.creativity.rationale, $categories.harness.rationale, $categories.lobster.rationale)
  }
}

function Escape-Html {
  param([string]$Value)
  return [System.Net.WebUtility]::HtmlEncode($Value)
}

function New-ReportHtml {
  param($Payload)
  $rows = New-Object System.Text.StringBuilder
  $sections = New-Object System.Text.StringBuilder
  foreach ($result in @($Payload.results)) {
    [void]$rows.Append("<tr><td>$(Escape-Html $result.name)</td><td>$(Escape-Html $result.repo_url)</td><td>$($result.categories.product.points)</td><td>$($result.categories.creativity.points)</td><td>$($result.categories.harness.points)</td><td>$($result.categories.lobster.points)</td><td>$($result.total)</td></tr>")
    $warningItems = (@($result.warnings) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { "<li>$(Escape-Html $_)</li>" }) -join ""
    if (-not $warningItems) { $warningItems = "<li>None</li>" }
    $screenshotItems = (@($result.screenshots) | ForEach-Object { "<li>$(Escape-Html $_)</li>" }) -join ""
    if (-not $screenshotItems) { $screenshotItems = "<li>None</li>" }
    $rationaleItems = (@($result.rationale) | ForEach-Object { "<li>$(Escape-Html $_)</li>" }) -join ""
    [void]$sections.Append("<section><h2>$(Escape-Html $result.name)</h2><h3>Warnings</h3><ul>$warningItems</ul><h3>Screenshots</h3><ul>$screenshotItems</ul><h3>Evidence Notes</h3><ul>$rationaleItems</ul></section>")
  }
  return @"
<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><title>thon-judge report</title>
<style>body{font-family:Arial,sans-serif;margin:24px;color:#17202a}table{border-collapse:collapse;width:100%;margin-bottom:24px}th,td{border:1px solid #ccd1d1;padding:8px;text-align:left;vertical-align:top}th{background:#f4f6f7}section{border-top:2px solid #d5dbdb;padding-top:12px}</style>
</head>
<body>
<h1>thon-judge preliminary report</h1>
<p>Input: $(Escape-Html $Payload.input)</p>
<table><thead><tr><th>Participant</th><th>Repository</th><th>Product</th><th>Creativity</th><th>Harness</th><th>Lobster</th><th>Total</th></tr></thead><tbody>$rows</tbody></table>
$sections
</body></html>
"@
}

function Write-JsonFile {
  param([string]$Path, $Payload)
  $parent = Split-Path -Parent $Path
  if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
  $Payload | ConvertTo-Json -Depth 12 | Set-Content -Encoding UTF8 $Path
}

$argsMap = Get-ArgsMap $Rest
try {
  switch ($Command) {
    "parse" {
      $inputPath = Require-Arg $argsMap "input"
      $submissions = @(Read-Submissions $inputPath)
      $json = ($submissions | ConvertTo-Json -Depth 12)
      if ($argsMap.ContainsKey("output")) { Write-JsonFile ([string]$argsMap["output"]) $submissions } else { Write-Output $json }
      exit 0
    }
    "criteria" {
      $criteria = Get-Criteria (Require-Arg $argsMap "criteria")
      $signals = Get-HarnessSignals (Require-Arg $argsMap "cases")
      $payload = [pscustomobject]@{ weights = $criteria; total_weight = ($criteria.Values | Measure-Object -Sum).Sum; signals = $signals }
      Write-JsonFile (Require-Arg $argsMap "output") $payload
      exit 0
    }
    "judge" {
      $inputPath = Require-Arg $argsMap "input"
      $criteriaPath = Require-Arg $argsMap "criteria"
      $casesPath = Require-Arg $argsMap "cases"
      $outputPath = Require-Arg $argsMap "output"
      [void](Get-Criteria $criteriaPath)
      [void](Get-HarnessSignals $casesPath)
      $fixtureDir = if ($argsMap.ContainsKey("github-fixtures")) { [string]$argsMap["github-fixtures"] } else { "" }
      $results = @()
      foreach ($submission in @(Read-Submissions $inputPath)) {
        $github = Get-GithubEvidence $submission.repo_url $fixtureDir
        $results += Get-Score $submission $github
      }
      $payload = [pscustomobject]@{ input = $inputPath; results = $results }
      $outParent = Split-Path -Parent $outputPath
      if ($outParent) { New-Item -ItemType Directory -Force -Path $outParent | Out-Null }
      New-ReportHtml $payload | Set-Content -Encoding UTF8 $outputPath
      if ($argsMap.ContainsKey("evidence")) { Write-JsonFile ([string]$argsMap["evidence"]) $payload }
      Write-Output "wrote report: $outputPath"
      if ($argsMap.ContainsKey("evidence")) { Write-Output "wrote evidence: $($argsMap["evidence"])" }
      exit 0
    }
    "fixtures" {
      $examples = if ($argsMap.ContainsKey("examples")) { [string]$argsMap["examples"] } else { Split-Path -Parent (Require-Arg $argsMap "input") }
      $files = Get-ChildItem -Path $examples -File -Include "*.json", "*.md", "*.txt" -Recurse | Select-Object -ExpandProperty FullName
      $payload = [pscustomobject]@{ files = $files }
      if ($argsMap.ContainsKey("output")) { Write-JsonFile ([string]$argsMap["output"]) $payload } else { $payload | ConvertTo-Json -Depth 4 }
      exit 0
    }
    "doctor" {
      $root = if ($argsMap.ContainsKey("plugin-root")) { [string]$argsMap["plugin-root"] } else { "." }
      foreach ($rel in @(".codex-plugin/plugin.json", "skills/thon-judge/SKILL.md", "scripts/thon-judge.ps1", "scripts/thon-judge.cmd")) {
        if (-not (Test-Path -LiteralPath (Join-Path $root $rel))) { Fail "missing plugin file $rel" }
      }
      Write-Output "thon-judge plugin OK"
      exit 0
    }
    default {
      Fail "unknown command $Command"
    }
  }
} catch {
  if ($env:THON_JUDGE_DEBUG) {
    [Console]::Error.WriteLine($_.ScriptStackTrace)
  }
  Fail $_.Exception.Message
}
