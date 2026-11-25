$ErrorActionPreference = 'Stop'
$scriptPath = $MyInvocation.MyCommand.Path
$splash = $null
$argList = @($args)
$quiet = @('--selftest', '--sshtest', '--render-ui', '--exit', '--demo-shell', '--write-assets') | Where-Object { $argList -contains $_ }

function Show-Splash {
    $existing = $null
    if ([System.Threading.Mutex]::TryOpenExisting('Local\SwitchDeck-6c1e2f94', [ref]$existing)) { $existing.Dispose(); return $null }
    $ab = [AppDomain]::CurrentDomain.DefineDynamicAssembly((New-Object Reflection.AssemblyName 'SwitchDeckSplash'), 'Run')
    $tb = $ab.DefineDynamicModule('SwitchDeckSplash').DefineType('SwitchDeckSplash.Native', 'Public,Class')
    [void]$tb.DefinePInvokeMethod('SetProcessDpiAwarenessContext', 'user32.dll', 'Public,Static,PinvokeImpl', 'Standard', [bool], [Type[]]@([IntPtr]), 'Winapi', 'Auto')
    [void]$tb.DefinePInvokeMethod('DwmSetWindowAttribute', 'dwmapi.dll', 'Public,Static,PinvokeImpl', 'Standard', [int], [Type[]]@([IntPtr], [int], [int].MakeByRefType(), [int]), 'Winapi', 'Auto')
    $native = $tb.CreateType()
    try { [void]$native::SetProcessDpiAwarenessContext([IntPtr](-4)) } catch { }
    $root = Split-Path -Parent (Split-Path -Parent $scriptPath)
    $assets = Join-Path $root 'assets'
    $g = [System.Drawing.Graphics]::FromHwnd([IntPtr]::Zero)
    $sc = $g.DpiX / 96.0
    $g.Dispose()
    $fonts = New-Object System.Drawing.Text.PrivateFontCollection
    foreach ($f in 'Poppins-SemiBold.ttf', 'Inter-Regular.ttf') {
        $p = Join-Path $assets ('fonts\' + $f)
        if (Test-Path $p) { $fonts.AddFontFile($p) }
    }
    $head = 'Segoe UI Semibold'; $body = 'Segoe UI'
    foreach ($fam in $fonts.Families) {
        if ($fam.Name -like '*Poppins*') { $head = $fam }
        if ($fam.Name -like '*Inter*') { $body = $fam }
    }
    $charcoal = [System.Drawing.Color]::FromArgb(32, 37, 43)
    $form = New-Object System.Windows.Forms.Form
    $form.FormBorderStyle = 'None'
    $form.StartPosition = 'CenterScreen'
    $form.ShowInTaskbar = $true
    $form.Text = 'SwitchDeck'
    $form.BackColor = $charcoal
    $form.ClientSize = New-Object System.Drawing.Size ([int](360 * $sc)), ([int](250 * $sc))
    $ico = Join-Path $assets 'icon.ico'
    if (Test-Path $ico) { $form.Icon = New-Object System.Drawing.Icon $ico }
    $logoPath = Join-Path $assets 'logo.png'
    if (Test-Path $logoPath) {
        $logo = New-Object System.Windows.Forms.PictureBox
        $logo.SizeMode = 'Zoom'
        $logo.Image = [System.Drawing.Image]::FromFile($logoPath)
        $logo.Size = New-Object System.Drawing.Size ([int](72 * $sc)), ([int](72 * $sc))
        $logo.Location = New-Object System.Drawing.Point ([int](($form.ClientSize.Width - $logo.Width) / 2)), ([int](40 * $sc))
        $form.Controls.Add($logo)
    }
    $title = New-Object System.Windows.Forms.Label
    $title.UseCompatibleTextRendering = $true
    $title.Text = 'SwitchDeck'
    $title.ForeColor = [System.Drawing.Color]::FromArgb(245, 243, 239)
    $title.Font = New-Object System.Drawing.Font($head, [single](20 * $sc), [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
    $title.TextAlign = 'MiddleCenter'
    $title.SetBounds(0, [int](122 * $sc), $form.ClientSize.Width, [int](34 * $sc))
    $form.Controls.Add($title)
    $sub = New-Object System.Windows.Forms.Label
    $sub.UseCompatibleTextRendering = $true
    $sub.Text = if ([Globalization.CultureInfo]::CurrentUICulture.TwoLetterISOLanguageName -eq 'fr') { 'Chargement...' } else { 'Loading...' }
    $sub.ForeColor = [System.Drawing.Color]::FromArgb(163, 170, 177)
    $sub.Font = New-Object System.Drawing.Font($body, [single](13 * $sc), [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
    $sub.TextAlign = 'MiddleCenter'
    $sub.SetBounds(0, [int](158 * $sc), $form.ClientSize.Width, [int](22 * $sc))
    $form.Controls.Add($sub)
    $novaPath = Join-Path $assets 'nova.png'
    $powered = New-Object System.Windows.Forms.Label
    $powered.UseCompatibleTextRendering = $true
    $powered.Text = 'Powered by Nova'
    $powered.ForeColor = [System.Drawing.Color]::FromArgb(111, 118, 126)
    $powered.Font = New-Object System.Drawing.Font($body, [single](11.5 * $sc), [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
    $powered.AutoSize = $true
    $form.Controls.Add($powered)
    $pw = $powered.PreferredWidth
    $nw = [int](18 * $sc)
    $x = [int](($form.ClientSize.Width - $pw - $nw - 6 * $sc) / 2)
    $y = [int](212 * $sc)
    if (Test-Path $novaPath) {
        $nova = New-Object System.Windows.Forms.PictureBox
        $nova.SizeMode = 'Zoom'
        $nova.Image = [System.Drawing.Image]::FromFile($novaPath)
        $nova.SetBounds($x, $y, $nw, $nw)
        $form.Controls.Add($nova)
        $x += $nw + [int](6 * $sc)
    }
    $powered.Location = New-Object System.Drawing.Point $x, ([int]($y + ($nw - $powered.PreferredHeight) / 2))
    $form.Show()
    try {
        $round = 2
        [void]$native::DwmSetWindowAttribute($form.Handle, 33, [ref]$round, 4)
        $dark = 1
        [void]$native::DwmSetWindowAttribute($form.Handle, 20, [ref]$dark, 4)
    } catch { }
    $form.Refresh()
    [System.Windows.Forms.Application]::DoEvents()
    return $form
}

$sources = @(
##SOURCES##
)

try {
    Add-Type -AssemblyName System.Windows.Forms, System.Drawing
    if (-not $quiet) { try { $splash = Show-Splash } catch { $splash = $null } }
    $joined = [string]::Join("`n", [string[]]$sources)
    $sha = [Security.Cryptography.SHA256]::Create()
    $hash = [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($joined))).Replace('-', '').Substring(0, 24)
    $cacheDir = Join-Path $env:LOCALAPPDATA 'SwitchDeck\cache'
    $cacheFile = Join-Path $cacheDir ($hash + '.bin')
    $assembly = $null
    if (Test-Path $cacheFile) {
        try { $assembly = [Reflection.Assembly]::Load([IO.File]::ReadAllBytes($cacheFile)) } catch { $assembly = $null }
    }
    if ($null -eq $assembly) {
        $provider = New-Object Microsoft.CSharp.CSharpCodeProvider
        $cp = New-Object System.CodeDom.Compiler.CompilerParameters
        $out = Join-Path ([IO.Path]::GetTempPath()) ('SwitchDeck-' + [Guid]::NewGuid().ToString('N') + '.dll')
        $cp.GenerateInMemory = $false
        $cp.GenerateExecutable = $false
        $cp.OutputAssembly = $out
        $cp.CompilerOptions = '/optimize+'
        foreach ($r in 'System.dll','System.Core.dll','System.Drawing.dll','System.Windows.Forms.dll','System.Security.dll') {
            [void]$cp.ReferencedAssemblies.Add($r)
        }
        if ($splash) { [System.Windows.Forms.Application]::DoEvents() }
        $result = $provider.CompileAssemblyFromSource($cp, [string[]]$sources)
        if ($result.Errors.HasErrors) {
            $msg = ($result.Errors | Where-Object { -not $_.IsWarning } | Select-Object -First 5 | ForEach-Object { $_.ToString() }) -join "`n"
            throw "SwitchDeck could not start:`n$msg"
        }
        $bytes = [IO.File]::ReadAllBytes($out)
        Remove-Item $out -ErrorAction SilentlyContinue
        Remove-Item ([IO.Path]::ChangeExtension($out, '.pdb')) -ErrorAction SilentlyContinue
        try {
            New-Item -ItemType Directory -Force $cacheDir | Out-Null
            Get-ChildItem $cacheDir -Filter *.bin -ErrorAction SilentlyContinue | Remove-Item -ErrorAction SilentlyContinue
            [IO.File]::WriteAllBytes($cacheFile, $bytes)
        } catch { }
        $assembly = [Reflection.Assembly]::Load($bytes)
    }
    if ($splash) { [System.Windows.Forms.Application]::DoEvents() }
    $program = $assembly.GetType('SwitchDeck.Program')
    $method = $program.GetMethod('RunFromScript', [Type[]]@([string], [string[]], [object]))
    $splashObj = $null
    if ($splash) { $splashObj = $splash.psobject.BaseObject }
    $code = $method.Invoke($null, [object[]]@($scriptPath, [string[]]$args, $splashObj))
    exit $code
}
catch {
    $err = $_.Exception
    while ($err.InnerException) { $err = $err.InnerException }
    if ($splash) { try { $splash.Close() } catch { } }
    try {
        $logDir = Join-Path (Split-Path -Parent (Split-Path -Parent $scriptPath)) 'logs'
        New-Item -ItemType Directory -Force $logDir | Out-Null
        Add-Content -Path (Join-Path $logDir 'SwitchDeck.log') -Value ((Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff') + ' ERROR launcher: ' + $err.ToString())
    } catch { }
    if (-not $quiet) { [System.Windows.Forms.MessageBox]::Show($err.Message, 'SwitchDeck', 'OK', 'Error') | Out-Null }
    else { Write-Host $err.ToString() }
    exit 1
}
