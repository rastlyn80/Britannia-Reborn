# Listens once on the default microphone and writes what was said to -Out as
# JSON {"text","status","engine"} (UTF-8, no byte-order mark). Used by the
# developer edit panel's Talk button. Uses Windows speech recognition (the
# engine behind Win+H; needs "Online speech recognition" in Windows privacy
# settings) and falls back to the offline desktop recognizer. Audio stays with
# Windows; nothing is recorded by the game.
param([Parameter(Mandatory)][string]$Out,[int]$Seconds = 12)
$ErrorActionPreference = 'Stop'
$result = [ordered]@{ text = ''; status = ''; engine = ''; online = 'on' }
function Save { [IO.File]::WriteAllText($Out,($result | ConvertTo-Json),(New-Object Text.UTF8Encoding $false)) }
function Await($operation, [Type]$type) {
  $asTask = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' } | Select-Object -First 1
  $task = $asTask.MakeGenericMethod($type).Invoke($null, @($operation))
  if (!$task.Wait([TimeSpan]::FromSeconds($Seconds + 10))) { throw 'timed out' }
  $task.Result
}
try {
  Add-Type -AssemblyName System.Runtime.WindowsRuntime
  $null = [Windows.Media.SpeechRecognition.SpeechRecognizer, Windows.Media.SpeechRecognition, ContentType = WindowsRuntime]
  $recognizer = New-Object Windows.Media.SpeechRecognition.SpeechRecognizer
  $recognizer.Timeouts.InitialSilenceTimeout = [TimeSpan]::FromSeconds(6)
  $recognizer.Timeouts.EndSilenceTimeout = [TimeSpan]::FromSeconds(1.2)
  $compiled = Await ($recognizer.CompileConstraintsAsync()) ([Windows.Media.SpeechRecognition.SpeechRecognitionCompilationResult])
  if ([string]$compiled.Status -ne 'Success') { throw "constraints: $($compiled.Status)" }
  $heard = Await ($recognizer.RecognizeAsync()) ([Windows.Media.SpeechRecognition.SpeechRecognitionResult])
  $result.engine = "windows ($($recognizer.CurrentLanguage.LanguageTag))"
  $result.status = [string]$heard.Status
  $result.text = [string]$heard.Text
} catch {
  # Offline fallback: the desktop recognizer with free dictation.
  $online = $_.Exception.Message
  try {
    Add-Type -AssemblyName System.Speech
    $engine = New-Object System.Speech.Recognition.SpeechRecognitionEngine
    $engine.LoadGrammar((New-Object System.Speech.Recognition.DictationGrammar))
    $engine.SetInputToDefaultAudioDevice()
    $engine.InitialSilenceTimeout = [TimeSpan]::FromSeconds(6)
    $engine.EndSilenceTimeout = [TimeSpan]::FromSeconds(1.2)
    $heard = $engine.Recognize([TimeSpan]::FromSeconds($Seconds))
    $result.engine = "offline ($($engine.RecognizerInfo.Culture.Name)); online failed: $online"
    # The offline dictation guesses words out of room noise; keep only
    # confident results and say why otherwise.
    $result.status = if (!$heard) { 'NoSpeech' } elseif ($heard.Confidence -lt 0.6) { 'LowConfidence' } else { 'Success' }
    $result.text = if ($result.status -eq 'Success') { $heard.Text } else { '' }
    $result.online = 'off'
  } catch { $result.status = "Error: $online; offline: $($_.Exception.Message)" }
}
Save
