$projectPath = "C:\Users\Zeus\Desktop\Zeus_Projects\app\sortirencorse_pro"
$backupDir = "C:\Users\Zeus\Desktop\Zeus_Projects\app\backups"
$timestamp = Get-Date -Format "yyyy_MM_dd_HH_mm_ss"
$zipName = "Backup_SortirEnCorse_$timestamp.zip"
$zipPath = Join-Path $backupDir $zipName

Write-Host "Création de la sauvegarde en cours... Veuillez patienter."

if (-Not (Test-Path $backupDir)) {
    New-Item -ItemType Directory -Force -Path $backupDir
}

# On exclut les dossiers lourds et inutiles pour gagner de la place et du temps
$excludeFolders = @(".dart_tool", "build", ".git", ".pub-cache", ".idea", "build_outputs")

Compress-Archive -Path "$projectPath\*" -DestinationPath $zipPath -Update

Write-Host "=========================================="
Write-Host "SAUVEGARDE TERMINÉE AVEC SUCCÈS !"
Write-Host "Fichier créé : $zipPath"
Write-Host "=========================================="
Read-Host "Appuyez sur Entrée pour quitter..."
