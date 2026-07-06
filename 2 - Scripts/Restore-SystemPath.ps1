<#
.SYNOPSIS
    Restaure la variable d'environnement PATH du système (HKLM) de manière sécurisée.

.DESCRIPTION
    Ce script réécrit la variable PATH globale de la machine en plaçant systématiquement 
    les répertoires vitaux de l'OS (System32, PowerShell, OpenSSH) en tête de liste. 
    Il concatène ensuite les chemins vers les outils tiers fournis en paramètre, 
    en vérifiant au préalable que ces dossiers existent bien sur le disque.
    Une sauvegarde du PATH corrompu est créée sur le Bureau avant modification.

.PARAMETER CustomPaths
    Un tableau (Array) contenant les chemins des logiciels tiers à ajouter au PATH.

.EXAMPLE
    .\Restore-SystemPath.ps1 -CustomPaths "C:\Program Files\nodejs\", "C:\Program Files\Git\cmd"
#>

#Requires -RunAsAdministrator

[CmdletBinding()]
param (
    [string[]]$CustomPaths = @(
        "C:\Program Files\nodejs\",
        "C:\Program Files\dotnet\",
        "C:\Program Files\Git\cmd",
        "C:\Program Files\PuTTY\"
    )
)

try {
    Write-Host "[INFO] Démarrage de la restauration du PATH Système..." -ForegroundColor Cyan

    # 1. Sauvegarde de sécurité
    $CurrentPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::Machine)
    $BackupFile = "$([Environment]::GetFolderPath('Desktop'))\PATH_Backup_$(Get-Date -Format 'yyyyMMdd_HHmm').txt"
    $CurrentPath | Out-File -FilePath $BackupFile
    Write-Host "[OK] Sauvegarde de l'ancien PATH créée sur le Bureau : $BackupFile" -ForegroundColor Green

    # 2. Déclaration stricte des fichiers OS Vitaux
    $CheminsVitaux = "C:\Windows\system32;C:\Windows;C:\Windows\System32\Wbem;C:\Windows\System32\WindowsPowerShell\v1.0;C:\Windows\System32\OpenSSH\"

    # 3. Validation et filtrage des chemins tiers
    $ValidThirdPartyPaths = @()
    foreach ($Path in $CustomPaths) {
        if (Test-Path -Path $Path) {
            $ValidThirdPartyPaths += $Path.TrimEnd('\') # Nettoyage du format
        } else {
            Write-Host "[WARN] Chemin ignoré car introuvable sur le disque : $Path" -ForegroundColor Yellow
        }
    }

    # 4. Concaténation et Injection
    $CheminsTiers = $ValidThirdPartyPaths -join ";"
    $NouveauSystemPath = "$CheminsVitaux;$CheminsTiers"

    [Environment]::SetEnvironmentVariable("Path", $NouveauSystemPath, [EnvironmentVariableTarget]::Machine)
    
    Write-Host "[SUCCÈS] Le PATH Système a été restauré avec succès." -ForegroundColor Green
    Write-Host "[ACTION] Veuillez redémarrer vos terminaux pour appliquer les changements." -ForegroundColor Cyan

} catch {
    Write-Host "[ERREUR CRITIQUE] Une erreur est survenue lors de la modification du Registre." -ForegroundColor White -BackgroundColor DarkRed
    Write-Host $_.Exception.Message -ForegroundColor Red
}