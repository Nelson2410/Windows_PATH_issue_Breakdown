# WinPath Recovery Toolkit

[![Windows](https://img.shields.io/badge/Windows-0078D6?style=for-the-badge&logo=windows&logoColor=white)](https://www.microsoft.com/windows)
[![PowerShell](https://img.shields.io/badge/PowerShell-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/powershell/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge)](./license)

Suite d'ingénierie système pour diagnostiquer, restaurer et sécuriser la variable d'environnement globale `PATH` sous Windows face aux corruptions et écrasements logiciels.

---

## Table des matieres

1. [Presentation](#presentation)
2. [Architecture du PATH Windows](#architecture-du-path-windows)
3. [Diagnostic d'un incident](#diagnostic-dun-incident)
4. [Script de restauration](#script-de-restauration)
5. [Script de monitoring](#script-de-monitoring)
6. [Organisation du projet](#organisation-du-projet)
7. [Guide d'utilisation](#guide-dutilisation)
8. [Auteur](#auteur)
9. [Licence](#licence)

---

## Presentation

### Contexte

Lorsque les commandes systeme fondamentales de Windows (`ipconfig`, `ping`, `reg`, `nslookup`) retournent l'erreur :

> *"Le terme n'est pas reconnu comme nom d'applet de commande, fonction, fichier de script ou programme executable."*

Le diagnostic revele presque toujours une **rupture de routage systeme** via la variable d'environnement `PATH`, et non une disparition des binaires executables eux-memes. Les fichiers resident toujours dans `C:\Windows\System32` ; c'est le chemin d'acces vers ce repertoire qui a ete efface de la variable globale.

### Objectif du toolkit

Ce projet propose une methodologie formelle et deux utilitaires PowerShell visant a :

- **Restaurer** la variable `PATH` systeme apres un ecrasement logiciel.
- **Securiser** le poste de travail en isolant les outils tiers dans la ruche utilisateur (`HKCU`).
- **Monitorer** passivement l'integrite du `PATH` a chaque ouverture de terminal.

Les principes directeurs s'appuient sur l'**Infrastructure as Code (IaC)**, le **moindre privilege** et le **monitoring passif**.

---

## Architecture du PATH Windows

### Mecanisme de construction

Au demarrage de chaque processus ou terminal, Windows construit la variable `PATH` finale en combinant les chemins de deux ruches de registre distinctes :

```
PATH Final = PATH Machine (HKLM) + PATH Utilisateur (HKCU)
```

### Les deux ruches de registre

| Propriete | Ruche Machine (HKLM) | Ruche Utilisateur (HKCU) |
| :--- | :--- | :--- |
| Chemin registre | `HKLM\System\CurrentControlSet\Control\Session Manager\Environment` | `HKCU\Environment` |
| Perimetre | Global (tout l'OS, tous les utilisateurs) | Local (utilisateur actif uniquement) |
| Privileges requis | Administrateur (`runas`) | Utilisateur standard |
| Contenu standard | `System32`, `Wbem`, `PowerShell`, `OpenSSH` | Outils developpement (`npm`, `Python`, `VS Code`) |

### Origines de corruption

1. **Affectation destructrice (`SET` au lieu d'`APPEND`)** : un installeur ecrase l'integralite de la variable avec ses propres chemins au lieu de les concatener.

2. **Troncature silencieuse (limite des 2047 caracteres)** : la variable d'environnement systeme est contrainte a **2047 caracteres**. Tout depassement provoque une amputation brutale des chemins excédentaires.

---

## Diagnostic d'un incident

### Scene de l'incident

Un utilisateur installe un environnement de developpement (Node.js, .NET, Git, etc.) avec privileges administrateur. L'installeur utilise une affectation absolue (`SET PATH=C:\Program Files\nodejs`) au lieu d'une concatenation. La variable systeme perd alors tous les chemins vitaux de Windows.

### Analyse bas niveau (hors PATH)

Lorsque le `PATH` est rompu, les executables systeme ne peuvent plus etre resolus par nom court. L'analyse repose sur les cmdlets PowerShell et les classes .NET chargees en memoire vive, qui fonctionnent independamment du `PATH` :

**Etape 1 : Inspection de la session active**

```powershell
$env:PATH -split ';'
```

*Constat* : absence de `C:\Windows\system32` ; seuls les repertoires tiers recents apparaissent.

**Etape 2 : Interrogation directe du registre (HKLM)**

```powershell
(Get-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Session Manager\Environment').PATH -split ';'
```

*Constat* : l'ecrasement est confirme dans la ruche globale (Machine).

### Diagnostic differentiel

Un diagnostic differentiel peut etre realise en comparant la session active et la ruche `HKLM`. Si les deux presentent la meme absence de chemins vitaux, l'origine est bien un ecrasement de la variable globale.

---

## Script de restauration

**Fichier :** [`Restore-SystemPath.ps1`](./2%20-%20Scripts/Restore-SystemPath.ps1)

### Description

Le script `Restore-SystemPath.ps1` reconstruit la variable d'environnement globale `PATH` au niveau de la ruche `Machine` (HKLM) de maniere securisee et deterministe.

### Fonctionnalites

| Fonctionnalite | Description |
| :--- | :--- |
| Sauvegarde a chaud | Cree un fichier horodate sur le Bureau (`PATH_Backup_YYYYMMDD_HHMM.txt`) avant toute modification |
| Chemins vitaux garantis | Reinsere systematiquement `System32`, `Wbem`, `PowerShell` et `OpenSSH` en tete de liste |
| Validation des chemins | Verifie l'existence physique de chaque repertoire tiers avant de l'ajouter au registre |
| Parametrage personnalise | Accepte un tableau de chemins personnalises via le parametre `-CustomPaths` |
| Ecriture atomique | Utilise l'API .NET `[Environment]::SetEnvironmentVariable` pour une ecriture propre sans dependance externe |

### Comportement par defaut

Sans parametre, le script restaure les chemins vitaux de l'OS et ajoute les repertoires tiers par defaut :

- `C:\Program Files\nodejs\`
- `C:\Program Files\dotnet\`
- `C:\Program Files\Git\cmd`
- `C:\Program Files\PuTTY\`

Les repertoires inexistants sur le disque sont ignores avec un avertissement (`[WARN]`).

### Pre-requis

- Console PowerShell ouverte en tant qu'**Administrateur** (modification de la ruche `HKLM`)
- La directive `#Requires -RunAsAdministrator` empeche l'execution sans elevation

### Execution

```powershell
# 1. Ouvrir PowerShell en mode Administrateur

# 2. Contourner la restriction d'execution pour la session courante
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

# 3. Restauration avec les chemins par defaut
& ".\2 - Scripts\Restore-SystemPath.ps1"

# 4. Restauration avec des chemins personnalises
& ".\2 - Scripts\Restore-SystemPath.ps1" -CustomPaths "C:\Program Files\nodejs\", "C:\Program Files\Git\cmd", "C:\Dossier\MonOutil"
```

### Gestion des erreurs

En cas d'echec de l'ecriture dans le registre, le script capture l'exception et affiche un message d'erreur critique sans effectuer de modification partielle.

---

## Script de monitoring

**Fichier :** [`Install-PathMonitor.ps1`](./2%20-%20Scripts/Install-PathMonitor.ps1)

### Description

Le script `Install-PathMonitor.ps1` injecte un module de verification dans le fichier de profil PowerShell (`$PROFILE`) de l'utilisateur. A chaque ouverture d'un nouveau terminal, l'integrite du `PATH` machine est validee automatiquement.

### Fonctionnement

```powershell
# --- MONITORING D'INTEGRITE DU PATH ---
$SysPathCheck = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::Machine)
if ($SysPathCheck -notmatch "(?i)C:\\Windows\\system32") {
    Write-Host "[ALERTE] Le PATH Systeme a ete alteRe. Chemins vitaux manquants." -ForegroundColor White -BackgroundColor DarkRed
}
```

### Signalement en cas d'anomalie

Si une corruption est detectee au lancement du terminal, l'alerte suivante apparait :

```
[ALERTE] Le PATH Systeme a ete alteRe. Chemins vitaux manquants.
```

Le message s'affiche en blanc sur fond rouge pour une visibilite maximale.

### Securite anti-doublon

Le script verifie la presence du code de monitoring dans le profil avant injection pour eviter les repetitions. Si le bloc `"MONITORING D'INTEGRITE DU PATH"` est deja present, l'injection est ignoree.

### Execution

```powershell
# Installer ou mettre a jour le garde-fou
& ".\2 - Scripts\Install-PathMonitor.ps1"
```

---

## Organisation du projet

```
WinPath-Recovery-Toolkit/
├── 1 - Docs/
│   ├── Path_Issue_Rapport.pdf       # Livre blanc - rapport d'incident detaille
│   └── Rapport_slides.pdf           # Support de presentation synthetique
├── 2 - Scripts/
│   ├── Restore-SystemPath.ps1       # Script curatif de restauration du registre
│   ├── Install-PathMonitor.ps1      # Script preventif d'injection du garde-fou
│   └── .gitignore                   # Fichier d'exclusion Git
├── license                          # Licence MIT
└── README.md                        # Documentation technique
```

### Liens directs

- [Livre blanc - Rapport d'incident](./1%20-%20Docs/Path_Issue_Rapport.pdf)
- [Support de presentation](./1%20-%20Docs/Rapport_slides.pdf)
- [Script de restauration](./2%20-%20Scripts/Restore-SystemPath.ps1)
- [Script d'installation du watchdog](./2%20-%20Scripts/Install-PathMonitor.ps1)
- [Licence MIT](./license)

---

## Guide d'utilisation

### Principes de securite

1. **Isolation des outils tiers** : installer les environnements de developpement (Node.js, Python, VS Code) pour l'**Utilisateur actuel** uniquement. L'installeur modifiera alors le `PATH` `HKCU` sans alterer le `PATH` `HKLM`.

2. **Profil PowerShell** : le fichier `$PROFILE` doit etre reserve au parametrage du moteur en cours d'execution (PowerShell 5.1 ou Core 7+). La selection du moteur par defaut se configure dans **Windows Terminal**.

3. **Sauvegarde prealable** : le script `Restore-SystemPath.ps1` effectue automatiquement une sauvegarde de la variable corrompue avant modification.

### Deroulement complet

1. **Diagnostiquer** : verifier `$env:PATH` et le registre `HKLM` pour confirmer l'ecrasement.
2. **Sauvegarder** : la sauvegarde est automatique lors de l'execution du script de restauration.
3. **Restaurer** : executer `Restore-SystemPath.ps1` en mode Administrateur.
4. **Monitorer** : executer `Install-PathMonitor.ps1` pour deployer le garde-fou.
5. **Valider** : ouvrir un nouveau terminal et verifier que les commandes systeme repondent correctement.

---

## Auteur

**Nelson Bandos** - Administrateur Reseau & Systeme

- [LinkedIn](https://www.linkedin.com/in/nelson-bandos)
- [Portfolio](https://nelson-bandos.vercel.app)
- Etude de cas realisee le 5 juillet 2026

---