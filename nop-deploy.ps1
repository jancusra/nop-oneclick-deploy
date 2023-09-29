$ErrorActionPreference = "Stop";
$nopDir = "C:\Down\nop";

$siteName = $PSScriptRoot | split-path -leaf;
$site = @{Name = $siteName};
$pool = @{Name = $site.Name + " v4.0 (Integrated)"};
$siteData = Get-Website @site;
$webStatus = Get-WebsiteState @site;
$poolStatus = Get-WebAppPoolState @pool;

if ($webStatus.Value -ne "Stopped") {
    Write-Host "Stopping WebSite ...";
    Stop-WebSite @site;
}
if ($poolStatus.Value -ne "Stopped") {
    Write-Host "Stopping WebAppPool ...";
    Stop-WebAppPool @pool;
    Start-Sleep -s 5;
}

$WPlist = Get-WmiObject -NameSpace 'root\WebAdministration' -class 'WorkerProcess' -ComputerName 'LocalHost';

foreach ($WP in $WPlist)
{
    if ($WP.AppPoolName -eq $pool.Name) 
    { 
        Write-Host "Killing pool process: PID:" $WP.ProcessId  "AppPool_Name:"$WP.AppPoolName;
        Stop-Process -ID $WP.ProcessId -Force;
        Start-Sleep -s 20;
    } 
}

$backupBase = "\backup";
$backupDir = $PSScriptRoot + $backupBase;
$siteDir = $siteData.physicalPath;

$itemsToBackupCopy = New-Object System.Collections.Generic.List[System.Object];
$itemsToBackupCopy.Add("\appsettings.json");
$itemsToBackupCopy.Add("\robots.custom.txt");
$itemsToBackupCopy.Add("\App_Data\dataSettings.json");
$itemsToBackupCopy.Add("\App_Data\plugins.json");
$itemsToBackupCopy.Add("\wwwroot\images\uploaded\");
$itemsToBackupCopy.Add("\wwwroot\files\");
$itemsToBackupCopy.Add("\wwwroot\favicon.ico");

$itemsToBackupMove = New-Object System.Collections.Generic.List[System.Object];
$itemsToBackupMove.Add("\wwwroot\images\thumbs\");

$themesDir = "\Themes";
$siteThemesDir = $siteDir + $themesDir;
$usedThemes = New-Object System.Collections.Generic.List[System.Object];
$themesDirs = Get-ChildItem -Path $siteThemesDir | ?{ $_.PSIsContainer };

foreach ($theme in $themesDirs) {
    $usedThemes.Add($theme.Name);
    $cssToBackup = $themesDir + "\" + $theme.Name + "\Content\css\theme.custom-1.css";
    $itemsToBackupCopy.Add($cssToBackup);
}

Write-Host "Creating web site backup ...";

New-Item -Force -Path $backupDir -ItemType Directory | Out-Null;

foreach ($item in $itemsToBackupCopy) {
    $sourceDir = $siteDir + $item;
    $destinDir = $backupDir + $item;

    if (Test-Path -Path $sourceDir -PathType Any) {
        if (Test-Path -Path $sourceDir -PathType Leaf) {
            New-Item -Path $destinDir -ItemType File -Force | Out-Null;
        }

        if (Test-Path -Path $sourceDir -PathType Container) {
            New-Item -Path $destinDir -ItemType Container -Force | Out-Null;
        }

        if ($destinDir.Chars($destinDir.Length - 1) -eq '\')
        {
            $destinDir = Split-Path $destinDir;
        }

        Copy-Item -Path $sourceDir -Destination $destinDir -Recurse -Force | Out-Null;
    }
}

foreach ($item in $itemsToBackupMove) {
    $sourceDir = $siteDir + $item;
    $destinDir = $backupDir + $item;

    if (Test-Path -Path $sourceDir -PathType Any) {
        Move-Item -Path $sourceDir -Destination $destinDir -Force | Out-Null;
    }
}

Write-Host "Removing web site files ...";

$keepFolder = $siteDir + "\.well-known*";
Get-ChildItem -Path $siteDir -Recurse |
Select -ExpandProperty FullName |
Where {$_ -notlike $keepFolder} |
Remove-Item -Recurse -Force | Out-Null;

Write-Host "Copying new web site files ...";

if (Test-Path -Path $nopDir -PathType Any) {
    Copy-Item -Path (Get-Item -Path "$nopDir\*" -Exclude ('Themes')).FullName -Destination $siteDir -Recurse -Force | Out-Null;

    foreach ($themeName in $usedThemes) {
        $nopThemeSource = $nopDir + $themesDir + "\" + $themeName + "\";
        $nopThemeDestin = $siteDir + $themesDir + "\" + $themeName + "\";
        Copy-Item -Path $nopThemeSource -Destination $nopThemeDestin -Recurse -Force | Out-Null;
    }
}

Write-Host "Restoring web site backup ...";

foreach ($item in $itemsToBackupMove) {
    $sourceDir = $backupDir + $item;
    $destinDir = $siteDir + $item;

    if (Test-Path -Path $sourceDir -PathType Any) {
        Remove-Item -Path $destinDir -Force -Recurse | Out-Null;
        Move-Item -Path $sourceDir -Destination $destinDir -Force | Out-Null;
    }
}

$backupDirContent = $backupDir + "\*";
Copy-Item -Path $backupDirContent -Destination $siteDir -Recurse -Force | Out-Null;

Write-Host "Starting WebAppPool ...";
Start-WebAppPool @pool;
Start-Sleep -s 5;
Write-Host "Starting WebSite ...";
Start-WebSite @site;
Write-Host "Success, everything done!";
