# Installs local, offline speech-to-text for the developer edit Talk button:
# whisper.cpp (MIT, ggml-org/whisper.cpp release b5454 = v1.9.5) and a
# multilingual Whisper model (MIT, OpenAI weights converted by ggerganov,
# huggingface.co/ggerganov/whisper.cpp at revision 5359861c). Everything goes
# to the ignored .tools/whisper folder; every download is pinned by SHA-256.
#   -Model small-q8_0          default: 252 MB, 99 languages, fast on CPU
#   -Model large-v3-turbo-q5_0 547 MB, best multilingual quality (use -Gpu)
#   -Gpu                       NVIDIA CUDA 11.8 build (272 MB) instead of CPU/BLAS
param([ValidateSet('base-q8_0','small-q8_0','large-v3-turbo-q5_0')][string]$Model = 'small-q8_0',[switch]$Gpu)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$folder = Join-Path $root '.tools/whisper'
New-Item -ItemType Directory -Force (Join-Path $folder 'models') | Out-Null
$release = 'https://github.com/ggml-org/whisper.cpp/releases/download/b5454'
$builds = @{
  cpu = @('whisper-blas-bin-x64.zip','B1158BD10EDF92C9799149A6FC5D3E58DA3F495241D6FB3423088130E88FFBF3')
  cuda = @('whisper-bin-win-cuda-11.8.0-x64.zip','E81C86C542BE6E3D7B7245392D4E1C52AB6E5C61DBE38721754BC0AB59D4D027')
}
$models = @{
  'base-q8_0' = 'C577B9A86E7E048A0B7EADA054F4DD79A56BBFA911FBDACF900AC5B567CBB7D9'
  'small-q8_0' = '49C8FB02B65E6049D5FA6C04F81F53B867B5EC9540406812C643F177317F779F'
  'large-v3-turbo-q5_0' = '394221709CD5AD1F40C46E6031CA61BCE88931E6E088C188294C6D5A55FFA7E2'
}
function Fetch($url, $path, $hash) {
  if ((Test-Path $path) -and (Get-FileHash $path).Hash -eq $hash) { return }
  Write-Output "Downloading $url"
  $ProgressPreference = 'SilentlyContinue'
  Invoke-WebRequest $url -OutFile "$path.part"
  if ((Get-FileHash "$path.part").Hash -ne $hash) { Remove-Item "$path.part"; throw "Checksum mismatch: $url" }
  Move-Item "$path.part" $path -Force
}
$kind = if ($Gpu) { 'cuda' } else { 'cpu' }
$archive = Join-Path $folder $builds[$kind][0]
Fetch "$release/$($builds[$kind][0])" $archive $builds[$kind][1]
$bin = Join-Path $folder $kind
if (!(Test-Path (Join-Path $bin 'whisper-cli.exe'))) {
  $unpack = Join-Path $folder "unpack-$kind"
  Remove-Item $unpack -Recurse -Force -ErrorAction SilentlyContinue
  Expand-Archive $archive $unpack
  $cli = Get-ChildItem $unpack -Recurse -Filter whisper-cli.exe | Select-Object -First 1
  if (!$cli) { throw 'whisper-cli.exe not found in the archive' }
  Remove-Item $bin -Recurse -Force -ErrorAction SilentlyContinue
  Move-Item $cli.Directory.FullName $bin
  Remove-Item $unpack -Recurse -Force
}
$modelPath = Join-Path $folder "models/ggml-$Model.bin"
Fetch "https://huggingface.co/ggerganov/whisper.cpp/resolve/5359861c739e955e79d9a303bcbc70fb988958b1/ggml-$Model.bin" $modelPath $models[$Model]
# The panel reads this to find the engine; delete it to fall back to Windows recognition.
$config = [ordered]@{ cli = (Join-Path $bin 'whisper-cli.exe'); model = $modelPath; build = "whisper.cpp b5454 $kind"; modelName = $Model }
[IO.File]::WriteAllText((Join-Path $folder 'speech.json'),($config | ConvertTo-Json),(New-Object Text.UTF8Encoding $false))
Write-Output "Speech-to-text ready: whisper.cpp b5454 ($kind), model $Model"
