param(
  [string]$TestName = "all"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$Script = Join-Path $Root "scripts/thon-judge.ps1"
$Cmd = Join-Path $Root "scripts/thon-judge.cmd"

function Assert-True {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) {
    throw $Message
  }
}

function Invoke-Judge {
  param([string[]]$CommandArgs)
  $output = & pwsh -NoProfile -ExecutionPolicy Bypass -File $Script @CommandArgs 2>&1
  [pscustomobject]@{ Code = $LASTEXITCODE; Output = ($output -join "`n") }
}

function Test-Scaffold {
  Assert-True (Test-Path (Join-Path $Root ".codex-plugin/plugin.json")) "plugin manifest missing"
  $manifest = Get-Content (Join-Path $Root ".codex-plugin/plugin.json") -Raw | ConvertFrom-Json
  Assert-True ($manifest.name -eq "thon-judge") "plugin id must be thon-judge"
  Assert-True ($manifest.skills -eq "./skills/") "manifest skills path mismatch"
  Assert-True ($manifest.scripts -eq "./scripts/") "manifest scripts path mismatch"
  Assert-True (Test-Path $Cmd) "cmd wrapper missing"
  Assert-True (Test-Path $Script) "PowerShell script missing"
}

function Test-Criteria {
  $out = Join-Path $Root ".omo/evidence/test-criteria.json"
  $result = Invoke-Judge @("criteria", "--criteria", (Join-Path $Root "JUDJE.md"), "--cases", (Join-Path $Root "cases"), "--output", $out)
  Assert-True ($result.Code -eq 0) "criteria command failed: $($result.Output)"
  $payload = Get-Content $out -Raw | ConvertFrom-Json
  Assert-True ($payload.total_weight -eq 100) "weights must sum to 100"
  Assert-True ($payload.weights.product -eq 35) "product weight mismatch"
  Assert-True ($payload.weights.creativity -eq 20) "creativity weight mismatch"
  Assert-True ($payload.weights.harness -eq 25) "harness weight mismatch"
  Assert-True ($payload.weights.lobster -eq 20) "lobster weight mismatch"
  Assert-True ($payload.signals.Count -ge 10) "expected at least 10 harness signals"
}

function Test-Schema {
  $json = Invoke-Judge @("parse", "--input", (Join-Path $Root "examples/submissions.json"))
  $md = Invoke-Judge @("parse", "--input", (Join-Path $Root "examples/submissions.md"))
  $txt = Invoke-Judge @("parse", "--input", (Join-Path $Root "examples/submissions.txt"))
  Assert-True ($json.Code -eq 0) "json parse failed"
  Assert-True ($md.Code -eq 0) "markdown parse failed"
  Assert-True ($txt.Code -eq 0) "txt parse failed"
  Assert-True ($json.Output -eq $md.Output) "json/md normalized output differs"
  Assert-True ($json.Output -eq $txt.Output) "json/txt normalized output differs"
}

function Test-Lobster {
  $out = Join-Path $Root ".omo/evidence/test-lobster.json"
  $result = Invoke-Judge @("judge", "--input", (Join-Path $Root "examples/lobster-boundary.json"), "--criteria", (Join-Path $Root "JUDJE.md"), "--cases", (Join-Path $Root "cases"), "--github-fixtures", (Join-Path $Root "examples/github"), "--output", (Join-Path $Root "reports/lobster.html"), "--evidence", $out)
  Assert-True ($result.Code -eq 0) "lobster judge failed: $($result.Output)"
  $payload = Get-Content $out -Raw | ConvertFrom-Json
  Assert-True ($payload.results[0].categories.lobster.points -eq 0) "lobster floor mismatch"
}

function Test-Report {
  $out = Join-Path $Root "reports/test-report.html"
  $evidence = Join-Path $Root ".omo/evidence/test-report.json"
  $result = Invoke-Judge @("judge", "--input", (Join-Path $Root "examples/submissions.json"), "--criteria", (Join-Path $Root "JUDJE.md"), "--cases", (Join-Path $Root "cases"), "--github-fixtures", (Join-Path $Root "examples/github"), "--output", $out, "--evidence", $evidence)
  Assert-True ($result.Code -eq 0) "judge failed: $($result.Output)"
  $html = Get-Content $out -Raw
  foreach ($text in @("Alpha", "Beta", "Product", "Creativity", "Harness", "Lobster", "Total")) {
    Assert-True ($html.Contains($text)) "report missing $text"
  }
}

function Test-Malformed {
  $result = Invoke-Judge @("judge", "--input", (Join-Path $Root "examples/malformed-submissions.md"), "--criteria", (Join-Path $Root "JUDJE.md"), "--cases", (Join-Path $Root "cases"), "--output", (Join-Path $Root "reports/bad.html"))
  Assert-True ($result.Code -ne 0) "malformed input should fail"
  Assert-True ($result.Output.Contains("validation error")) "malformed failure missing validation error"
}

$tests = [ordered]@{
  scaffold = ${function:Test-Scaffold}
  criteria = ${function:Test-Criteria}
  schema = ${function:Test-Schema}
  lobster = ${function:Test-Lobster}
  report = ${function:Test-Report}
  malformed = ${function:Test-Malformed}
}

if ($TestName -eq "all") {
  foreach ($name in $tests.Keys) {
    & $tests[$name]
    Write-Output "PASS $name"
  }
} else {
  Assert-True ($tests.Contains($TestName)) "unknown test $TestName"
  & $tests[$TestName]
  Write-Output "PASS $TestName"
}
