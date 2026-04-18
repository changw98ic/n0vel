$excludes = @('smart_segment_service.dart','pov_repository.dart','relationship_repository.dart')
$results = @()
Get-ChildItem -Path lib/ -Recurse -Filter *.dart | Where-Object { $excludes -notcontains $_.Name } | ForEach-Object {
    $bytes = [System.IO.File]::ReadAllBytes($_.FullName)
    $text = [System.Text.Encoding]::UTF8.GetString($bytes)
    # Check for Unicode replacement character (U+FFFD) which indicates broken encoding
    if ($text.Contains([char]0xFFFD)) {
        $count = ($text.ToCharArray() | Where-Object { $_ -eq [char]0xFFFD }).Count
        $results += "$($_.FullName): $count replacement chars (U+FFFD) found"
    }
}
if ($results.Count -eq 0) { Write-Output 'CLEAN: No broken encoding detected in non-excluded files' }
else { $results | ForEach-Object { Write-Output $_ } }
