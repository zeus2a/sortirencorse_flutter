$ErrorActionPreference = "Continue"

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host " ZEUS COMPILATION & SYNCHRONISATION AUTOMATIQUE" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Lire le fichier pubspec.yaml
if (-not (Test-Path "pubspec.yaml")) {
    Write-Host "Erreur : Fichier pubspec.yaml introuvable. Executez ce script depuis le dossier du projet." -ForegroundColor Red
    Pause
    Exit
}

$pubspec = Get-Content -Path "pubspec.yaml"
$versionLine = $pubspec | Where-Object { $_ -match "^version:\s+(.+)$" } | Select-Object -First 1

if (-not $versionLine) {
    Write-Host "Erreur : Impossible de trouver la ligne 'version:' dans pubspec.yaml" -ForegroundColor Red
    Pause
    Exit
}

# Extraction via regex
$versionString = $versionLine -replace "^version:\s+", ""
$versionParts = $versionString -split "\+"

if ($versionParts.Length -ne 2) {
    Write-Host "Erreur : Le format de version n'est pas valide (ex: 4.3.2+52 attendu)." -ForegroundColor Red
    Pause
    Exit
}

$v = $versionParts[0]
$b = $versionParts[1]

Write-Host "-> Version detectee : $v (Build $b)" -ForegroundColor Yellow
Write-Host ""

# 2. Mettre à jour le serveur O2Switch
Write-Host "-> Synchronisation avec le serveur API (api.corsemusicevents.fr)..."
$url = "https://api.corsemusicevents.fr/?action=set_version&v=$v&build=$b&key=ZeusCorsica2026"

try {
    # On force TLS 1.2 au cas où
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $response = Invoke-RestMethod -Uri $url -Method Get
    
    if ($response.status -eq "success") {
        Write-Host "[OK] Succes : Le serveur a bien enregistre la version $v (Build $b)!" -ForegroundColor Green
    } else {
        Write-Host "[!] Avertissement : Le serveur a repondu, mais avec une erreur." -ForegroundColor Yellow
        Write-Host $response.message
    }
} catch {
    Write-Host "[X] Erreur : Impossible de contacter le serveur API. Verifiez votre connexion internet." -ForegroundColor Red
    Write-Host $_.Exception.Message
}

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host " TERMINE ! Le serveur est maintenant synchronise." -ForegroundColor Cyan
Write-Host " (Vous pouvez demander a l'assistant IA de compiler l'application quand vous etes pret)." -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Pause
