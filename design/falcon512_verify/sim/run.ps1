# -------------------------------
# Author      : desktop-ifrf24e\najam
# Description : Compile and run the Falcon-512 verify self-checking bench.
#               Options are placed before source files because the Windows
#               Icarus build stops parsing options at the first source.
# -------------------------------
# Usage
#   .\run.ps1              compile and run, writing sim.log
#   .\run.ps1 -compile     compile only
#   .\run.ps1 -clean       remove generated files
# -------------------------------

$ErrorActionPreference = 'Continue'

function Invoke-Clean {
  Remove-Item -Path my_sim_exe, my_sim_exe.vvp, sim.log, simulation.vcd -Force -ErrorAction SilentlyContinue
  Write-Host "Generated simulation files cleaned."
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
    $Lines | Out-File -FilePath sim.log -Append -Encoding utf8
  } else {
    $Lines | Out-File -FilePath sim.log -Encoding utf8
  }
  $Lines | ForEach-Object { Write-Host $_ }
}

$mode = if ($args.Count -ge 1) { $args[0] } else { '' }
if ($mode -eq '-clean') { Invoke-Clean; exit 0 }
if ($mode -in '-h', '--help', '/?') {
  Write-Host 'Usage: .\run.ps1 [-compile|-clean]'
  exit 0
}

$iverilog = Find-Iverilog
$vvp = Find-Vvp

$compile_out = & $iverilog -s tb_falcon512_verify -g2012 -f f_list.f -o my_sim_exe tb_falcon512_verify.sv 2>&1
Write-Log $compile_out
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if ($mode -eq '-compile') { exit 0 }

$sim_out = & $vvp my_sim_exe 2>&1
Write-Log $sim_out -Append
$rc = $LASTEXITCODE
Remove-Item -Path my_sim_exe -Force -ErrorAction SilentlyContinue
exit $rc
