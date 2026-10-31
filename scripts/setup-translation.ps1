# Live translation (docs/VOICE_AND_TRANSLATION.md): a local, offline
# translator for chat and server text. Installs Argos Translate (MIT; neural
# models from the Argos package index, run on CPU by CTranslate2) and langid
# (BSD, language detection) into .tools/translate, then the English <-> language
# models for -Languages. Nothing is committed; text never leaves the computer.
param([string[]]$Languages = @('it','es','fr','de'))
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$venv = Join-Path $root '.tools/translate'
$python = Join-Path $venv 'Scripts/python.exe'
if (!(Test-Path $python)) {
  $base = (Get-Command python -ErrorAction Stop).Source
  & $base -m venv $venv
  if ($LASTEXITCODE) { throw 'Could not create the translation environment' }
}
& $python -m pip install --disable-pip-version-check --quiet 'argostranslate==1.9.6' 'langid==1.1.6'
if ($LASTEXITCODE) { throw 'Could not install Argos Translate' }
$env:ARGOS_PACKAGES_DIR = Join-Path $venv 'packages'
& $python (Join-Path $PSScriptRoot 'translate-server.py') --install ($Languages -join ',')
if ($LASTEXITCODE) { throw 'Could not install translation models' }
Write-Output "Live translation ready for: en, $($Languages -join ', '). Choose your language in Game menu > Voice and translation."
