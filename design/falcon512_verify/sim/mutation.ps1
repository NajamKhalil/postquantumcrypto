# -------------------------------
# Author      : desktop-ifrf24e\najam
# Description : Re-run the five recorded mutations against fresh copies of the
#               final RTL and bench. Copies live outside the repository under
#               LOCALAPPDATA\Temp\opencode; the committed sources are never
#               changed. Raw compile/run output is written to mutation.rpt so
#               the dashboard SIM gate does not read expected FAIL tokens as a
#               simulation failure.
# -------------------------------
# Usage
#   .\mutation.ps1          run M1-M5 and write mutation.rpt
#   .\mutation.ps1 -clean   remove mutation.rpt only
# -------------------------------

$ErrorActionPreference = 'Continue'

function Invoke-Clean {
  Remove-Item -Path mutation.rpt -Force -ErrorAction SilentlyContinue
  Write-Host "Mutation log cleaned."
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
    $Lines | Out-File -FilePath mutation.rpt -Append -Encoding utf8
  } else {
    $Lines | Out-File -FilePath mutation.rpt -Encoding utf8
  }
  $Lines | ForEach-Object { Write-Host $_ }
}

$mode = if ($args.Count -ge 1) { $args[0] } else { '' }
if ($mode -eq '-clean') { Invoke-Clean; exit 0 }
if ($mode -in '-h', '--help', '/?') {
  Write-Host 'Usage: .\mutation.ps1 [-clean]'
  exit 0
}

$block = Split-Path -Parent $PSScriptRoot
$tmp_root = Join-Path $env:LOCALAPPDATA 'Temp\opencode\falcon_regress_mut'
$mut_rtl = Join-Path $tmp_root 'rtl'
$mut_sim = Join-Path $tmp_root 'sim'
$iverilog = Find-Iverilog
$vvp = Find-Vvp

New-Item -ItemType Directory -Force -Path $mut_rtl, $mut_sim | Out-Null
Remove-Item -Path mutation.rpt -Force -ErrorAction SilentlyContinue

$tests = @(
  @{
    id = 'M1'
    file = 'rtl\falcon512_pkg.sv'
    pattern = "9: f_stage_root_inv = 16'd2859;"
    replace = "9: f_stage_root_inv = 16'd3400;"
    desc = 'inverse stage 9 root replaced by forward root'
  },
  @{
    id = 'M2'
    file = 'sim\tb_falcon512_verify.sv'
    pattern = 'sign = -1;'
    replace = 'sign = 1;'
    desc = 'negacyclic wrap sign removed from reference model'
  },
  @{
    id = 'M3'
    file = 'rtl\falcon512_verify.sv'
    pattern = 'verify_accept_q  <= (norm_q <= BETA_SQ_Q);'
    replace = 'verify_accept_q  <= (norm_q < BETA_SQ_Q);'
    desc = 'inclusive norm comparison changed to exclusive'
  },
  @{
    id = 'M4'
    file = 'rtl\falcon512_ntt.sv'
    pattern = 'LAST_BFLY  = BFLY_TOTAL - 1;'
    replace = 'LAST_BFLY  = BFLY_TOTAL - 2;'
    desc = 'butterfly count shortened by one'
  },
  @{
    id = 'M5'
    file = 'rtl\falcon512_verify.sv'
    pattern = 'ntt_load_data_q <= falcon512_pkg::f_mod_mul(falcon512_pkg::f_to_mod(s2_tdata), twist_q);'
    replace = 'ntt_load_data_q <= falcon512_pkg::f_to_mod(s2_tdata);'
    desc = 'PSI^i twist removed from loaded s2'
  }
)

Write-Log @("# mutation campaign $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
            "# source: $block",
            "# copies: $tmp_root")

$failed = 0
foreach ($t in $tests) {
  Copy-Item "$block\rtl\*.sv" $mut_rtl -Force
  Copy-Item "$block\sim\tb_falcon512_verify.sv" $mut_sim -Force

  $path = Join-Path $tmp_root $t.file
  $text = Get-Content $path -Raw
  $hits = [regex]::Matches($text, [regex]::Escape($t.pattern)).Count
  if ($hits -ne 1) {
    Write-Log "$($t.id) SETUP-FAIL pattern_hits=$hits $($t.desc)" -Append
    $failed = 1
    continue
  }
  $text = [regex]::Replace($text, [regex]::Escape($t.pattern), $t.replace)
  Set-Content -Path $path -Value $text -NoNewline

  $exe = Join-Path $tmp_root "$($t.id)_tb.exe"
  $sources = @(
    (Join-Path $mut_rtl 'falcon512_pkg.sv'),
    (Join-Path $mut_rtl 'falcon512_ntt.sv'),
    (Join-Path $mut_rtl 'falcon512_verify.sv'),
    (Join-Path $mut_sim 'tb_falcon512_verify.sv')
  )

  Write-Log "# $($t.id) $($t.desc)" -Append
  $compile_out = & $iverilog -g2012 -DRTL_SIM -s tb_falcon512_verify -o $exe @sources 2>&1 | ForEach-Object { $_.ToString() }
  $compile_rc = $LASTEXITCODE
  Write-Log $compile_out -Append
  if ($compile_rc -ne 0) {
    Write-Log "COMPILE-FAIL $($t.id)" -Append
    $failed = 1
    continue
  }

  $sim_out = & $vvp $exe 2>&1 | ForEach-Object { $_.ToString() }
  $sim_rc = $LASTEXITCODE
  Write-Log $sim_out -Append

  $pass_count = @($sim_out | Where-Object { $_ -match '^RESULT\s*=\s*PASS\b' }).Count
  $fail_count = @($sim_out | Where-Object { $_ -match '^RESULT\s*=\s*FAIL\b' }).Count
  if (($fail_count -ge 1) -and ($pass_count -eq 0)) {
    Write-Log "KILLED   $($t.id) - $($t.desc)" -Append
  } else {
    Write-Log "SURVIVED   $($t.id) - $($t.desc)" -Append
    $failed = 1
  }
}

if ($failed -eq 0) {
  Write-Log "MUTATION  = PASS   (5 killed, 0 survived)" -Append
} else {
  Write-Log "MUTATION  = FAIL   (check SETUP-FAIL, COMPILE-FAIL or SURVIVED rows)" -Append
}

Remove-Item -Path $tmp_root -Recurse -Force -ErrorAction SilentlyContinue
exit $failed
