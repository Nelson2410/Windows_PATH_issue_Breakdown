<#
.SYNOPSIS
    Installe un monitoring passif de la variable PATH dans le profil PowerShell.

.DESCRIPTION
    Ce script injecte un garde-fou dans le fichier $PROFILE de l'utilisateur. 
    À chaque lancement de PowerShell, l'interpréteur vérifiera silencieusement l'intégrité 
    du registre Système (HKLM). Si C:\Windows\System32 est manquant, une alerte critique s'affichera.

.EXAMPLE
    .\Install-PathMonitor.ps1
#>

[CmdletBinding()]
param ()

Write-Host "[INFO] Configuration du garde-fou dans le profil PowerShell..." -ForegroundColor Cyan

# 1. Vérification et création du fichier de profil si inexistant
if (!(Test-Path -Path $PROFILE)) {
    try {
        New-Item -ItemType File -Path $PROFILE -Force | Out-Null
        Write-Host "[OK] Fichier de profil créé : $PROFILE" -ForegroundColor Green
    } catch {
        Write-Host "[ERREUR] Impossible de créer le fichier de profil." -ForegroundColor Red
        exit
    }
} else {
    Write-Host "[OK] Fichier de profil existant trouvé." -ForegroundColor Green
}

# 2. Le code de monitoring à injecter
$MonitorPayload = @"

# --- MONITORING D'INTEGRITE DU PATH ---
`$SysPathCheck = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::Machine)
if (`$SysPathCheck -notmatch "(?i)C:\\Windows\\system32") {
    Write-Host "[ALERTE] Le PATH Systeme a ete altere. Chemins vitaux manquants." -ForegroundColor White -BackgroundColor DarkRed
}
# --------------------------------------
"@

# 3. Vérification de la présence du code pour éviter les doublons
$ProfileContent = Get-Content -Path $PROFILE -Raw
if ($ProfileContent -match "MONITORING D'INTEGRITE DU PATH") {
    Write-Host "[INFO] Le garde-fou est déjà installé dans votre profil. Aucune modification nécessaire." -ForegroundColor Yellow
} else {
    try {
        Add-Content -Path $PROFILE -Value $MonitorPayload
        Write-Host "[SUCCÈS] Le garde-fou a été injecté avec succès !" -ForegroundColor Green
        Write-Host "[TEST] Ouvrez un nouveau terminal PowerShell pour finaliser l'installation." -ForegroundColor Cyan
    } catch {
        Write-Host "[ERREUR] Impossible d'écrire dans le fichier de profil." -ForegroundColor Red
    }
}