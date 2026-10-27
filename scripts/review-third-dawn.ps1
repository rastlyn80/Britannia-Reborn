param([switch]$Compatibility, [string]$Screenshot = '', [switch]$Validate, [ValidateSet('Idle','Walk','Run')][string]$Clip = 'Idle', [switch]$Human, [switch]$FreeHuman, [switch]$Equipment, [ValidateSet('all','base','clothing','materials','head','bust','parts','robe')][string]$View = 'all', [ValidateSet('front','three-quarter','profile')][string]$Angle = 'front', [switch]$Rear, [ValidateSet('studio','side','outdoor')][string]$Light = 'studio', [string]$MaterialTest = '', [double]$Phase = .23)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$godot = (Get-ChildItem "$root/.tools/godot/*console.exe" | Select-Object -First 1).FullName
$env:APPDATA = Join-Path $root '.godot-user'
$env:LOCALAPPDATA = $env:APPDATA
New-Item -ItemType Directory -Force "$root/outputs/third-dawn" | Out-Null
if (!$Equipment) {
    foreach ($body in @('human','ogre')) {
        if (!(Test-Path "$root/Viewer/local-art/third-dawn/$body.gltf")) { throw 'Run scripts/import-third-dawn.py --archive PATH first.' }
    }
} elseif (!(Test-Path "$root/Viewer/local-art/free-equipment/equipment-base.glb")) {
    throw 'Prepare the CC0 equipment assets with scripts/prepare-free-equipment.py first.'
}
& $godot --headless --path "$root/Viewer" --editor --import
if ($LASTEXITCODE) { throw 'Godot import failed' }
if ($Equipment) {
    $changedMaps = $false
    foreach ($name in @('Aksel_Skin_diffuse.png','Aksel_Skin_NRM.png','Aksel_Skin_SPEC.png','young_lightskinned_male_diffuse2.png','young_lightskinned_male_diffuse3.png','young_darkskinned_male_diffuse.png')) {
        $importPath = Join-Path $root "Viewer/local-art/free-equipment/$name.import"
        $before = [IO.File]::ReadAllText($importPath)
        $after = $before.Replace('mipmaps/generate=false','mipmaps/generate=true')
        if ($name -like '*NRM*') { $after = $after.Replace('compress/normal_map=0','compress/normal_map=1') }
        if ($after -ne $before) {
            [IO.File]::WriteAllText($importPath,$after,[Text.UTF8Encoding]::new($false))
            $changedMaps = $true
        }
    }
    if ($changedMaps) {
        & $godot --headless --path "$root/Viewer" --editor --import
        if ($LASTEXITCODE) { throw 'Skin texture import failed' }
    }
}
$engineArgs = @('--path', "$root/Viewer", '--script', 'res://Presentation/ThirdDawnReview.gd')
if ($Compatibility) { $engineArgs += @('--rendering-method','gl_compatibility') }
if ($Validate -and !$Screenshot -and !$MaterialTest) { $engineArgs += '--headless' }
$userArgs = @("--clip=$Clip", "--view=$View", "--light=$Light", "--angle=$Angle", "--phase=$Phase")
if ($Human) { $userArgs += '--human' }
if ($FreeHuman) { $userArgs += '--free-human' }
if ($Equipment) { $userArgs += '--equipment' }
if ($Rear) { $userArgs += '--rear' }
if ($MaterialTest) { $userArgs += "--material-test=$([IO.Path]::GetFullPath($MaterialTest))" }
if ($Screenshot) { $userArgs += "--screenshot=$([IO.Path]::GetFullPath($Screenshot))" }
if ($Validate) { $userArgs += "--report=$root/outputs/third-dawn/$(if ($Human) {'human-validation'} else {'engine-validation'}).json" }
& $godot @engineArgs -- @userArgs
if ($LASTEXITCODE) { throw 'Third Dawn review failed' }
