# -------------------------------
# Author      : desktop-ifrf24e\najam
# Description : Compile the Falcon-512 verify bench once, then run several
#               deterministic +REGRESS configurations. Each configuration must
#               end with exactly one RESULT  = PASS and no RESULT  = FAIL.
#               Raw Icarus output is written to regress.log.
# -------------------------------
# Usage
#   .\regress.ps1          compile and run the regression sweep
#   .\regress.ps1 -clean   remove generated regression files
# -------------------------------

$ErrorActionPreference = 'Continue'

function Invoke-Clean {
  Remove-Item -Path my_sim_exe, my_sim_exe.vvp, regress.log -Force -ErrorAction SilentlyContinue
  Write-Host "Generated regression files cleaned."
}

function Find-Iverilog {
  if (Get-Command iverilog -ErrorAction SilentlyContinue) { return 'iverilog' }
  if (Test-Path 'C:\iverilog\bin\iverilog.exe') { return 'C:\iverilog\bin\iverilog.exe' }
  throw 'iverilog not found: install Icarus Verilog or add it to PATH.'
}

function Find-Vvp {
  if (Get-Command vvp -ErrorAction SilentlyContinue) { return 'vvp' }
  if (Test-Path 'C:\iverilog\bin\vvp.exe') { return 'C:\iverilog\bin\vvp.exe' }
  throw 'vvp not found: install Icarus Verilog or add it to PATH.'
}

function Write-Log {
  param([object[]] $Lines, [switch] $Append)
  if ($Append) {
    $Lines | Out-File -FilePath regress.log -Append -Encoding utf8
  } else {
    $Lines | Out-File -FilePath regress.log -Encoding utf8
  }
  $Lines | ForEach-Object { Write-Host $_ }
}

$mode = if ($args.Count -ge 1) { $args[0] } else { '' }
if ($mode -eq '-clean') { Invoke-Clean; exit 0 }
if ($mode -in '-h', '--help', '/?') {
  Write-Host 'Usage: .\regress.ps1 [-clean]'
  exit 0
}

$iverilog = Find-Iverilog
$vvp = Find-Vvp

Remove-Item -Path regress.log, my_sim_exe -Force -ErrorAction SilentlyContinue

$compile_out = & $iverilog -s tb_falcon512_verify -g2012 -f f_list.f -o my_sim_exe tb_falcon512_verify.sv 2>&1 | ForEach-Object { $_.ToString() }
Write-Log $compile_out
if ($LASTEXITCODE -ne 0) {
  Write-Log "REGRESSION  = FAIL   (compile failed)" -Append
  exit $LASTEXITCODE
}

$configs = @(
  @{ name = 'seed-sweep-a'; args = @('+REGRESS=1', '+SEED=101', '+SEED_COUNT=4', '+BP=0') },
  @{ name = 'seed-sweep-b'; args = @('+REGRESS=1', '+SEED=202', '+SEED_COUNT=2', '+BP=2') },
  @{ name = 'seed-sweep-c'; args = @('+REGRESS=1', '+SEED=303', '+SEED_COUNT=2', '+BP=3') }
)

$failed = 0
$total_runs = 0
foreach ($cfg in $configs) {
  Write-Log "# CONFIG $($cfg.name)  $($cfg.args -join ' ')" -Append

  $vvp_args = @('my_sim_exe') + $cfg.args
  $sim_out = & $vvp @vvp_args 2>&1 | ForEach-Object { $_.ToString() }
  $rc = $LASTEXITCODE
  Write-Log $sim_out -Append

  $pass_count = @($sim_out | Where-Object { $_ -match '^RESULT\s*=\s*PASS\b' }).Count
  $fail_count = @($sim_out | Where-Object { $_ -match '^RESULT\s*=\s*FAIL\b' }).Count
  $run_count = @($sim_out | Where-Object { $_ -match '^RUN ' }).Count
  $total_runs += $run_count

  if (($rc -ne 0) -or ($pass_count -ne 1) -or ($fail_count -ne 0)) {
    Write-Log "CONFIG $($cfg.name)  FAIL  rc=$rc  pass=$pass_count  fail=$fail_count  runs=$run_count" -Append
    $failed = 1
  } else {
    Write-Log "CONFIG $($cfg.name)  PASS  runs=$run_count" -Append
  }
}

if ($failed -eq 0) {
  Write-Log "REGRESSION  = PASS   ($($configs.Count) configurations, $total_runs runs)" -Append
} else {
  Write-Log "REGRESSION  = FAIL   ($total_runs runs)" -Append
}

Remove-Item -Path my_sim_exe -Force -ErrorAction SilentlyContinue
exit $failed
