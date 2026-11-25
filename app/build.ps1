$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path $csc)) { $csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe' }

$sourceFiles = Get-ChildItem (Join-Path $root 'src') -Filter *.cs | Sort-Object Name
$refs = 'System.dll','System.Core.dll','System.Drawing.dll','System.Windows.Forms.dll','System.Security.dll'

$check = Join-Path ([IO.Path]::GetTempPath()) ('SwitchDeck-check-' + [Guid]::NewGuid().ToString('N') + '.dll')
& $csc /nologo /target:library /langversion:5 /warn:4 /nowarn:1591 "/out:$check" ($refs | ForEach-Object { "/reference:$_" }) ($sourceFiles | ForEach-Object { $_.FullName })
$ok = $LASTEXITCODE -eq 0
Remove-Item $check -ErrorAction SilentlyContinue
if (-not $ok) { throw 'Compilation failed' }

$parts = foreach ($f in $sourceFiles) {
    $text = [IO.File]::ReadAllText($f.FullName)
    if ($text -match "(?m)^'@") { throw "$($f.Name) contains a line starting with '@" }
    "@'`r`n" + $text.TrimEnd().Replace("`r`n", "`n").Replace("`n", "`r`n") + "`r`n'@"
}
$template = [IO.File]::ReadAllText((Join-Path $root 'launcher.template.ps1'))
$ps1 = Join-Path $root 'SwitchDeck.ps1'
[IO.File]::WriteAllText($ps1, $template.Replace('##SOURCES##', ($parts -join ",`r`n")), (New-Object Text.UTF8Encoding($true)))

$cmd = "@echo off`r`n" +
       "start `"`" `"%SystemRoot%\System32\conhost.exe`" --headless `"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe`" " +
       "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"%~dp0app\SwitchDeck.ps1`"`r`n"
[IO.File]::WriteAllText((Join-Path (Split-Path -Parent $root) 'SwitchDeck.cmd'), $cmd)

Write-Host 'Built:' -ForegroundColor Green
Write-Host ('  app\SwitchDeck.ps1  (' + [math]::Round((Get-Item $ps1).Length / 1KB) + ' KB)')
Write-Host '  SwitchDeck.cmd'
