param([string[]]$Roots = @('C:\Games\Electronic Arts','C:\Program Files\Electronic Arts','C:\Program Files (x86)\Electronic Arts','C:\Program Files (x86)\EA Games',"$env:USERPROFILE\OneDrive\Electronic Arts"))
# Read-only inventory. Never launch the client, patch, or write to game directories.
foreach ($root in $Roots) {
  if (Test-Path -LiteralPath $root) {
    Get-ChildItem -LiteralPath $root -File -Recurse -ErrorAction SilentlyContinue |
      Where-Object Name -Match '^(map[01].*\.(mul|uop)|staidx1\.mul|statics1\.mul)$' |
      Select-Object FullName,Length,LastWriteTimeUtc
  }
}
