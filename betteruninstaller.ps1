Add-Type -AssemblyName System.Windows.Forms

$mainForm = New-Object System.Windows.Forms.Form
$mainForm.Text = "Better Uninstaller"
$mainForm.Width = 400
$mainForm.Height = 600

$appListBox = New-Object System.Windows.Forms.CheckedListBox
$appListBox.Dock = 'Fill'

$uninstallButton = New-Object System.Windows.Forms.Button
$uninstallButton.Text = "Uninstall"
$uninstallButton.Dock = 'Bottom'

# Mapping of display name to registry properties
$appDisplayNameToRegistry = @{}

$uninstallRegistryKeys = Get-ChildItem -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
foreach ($regKey in $uninstallRegistryKeys) {
    $appProps = Get-ItemProperty -Path $regKey.PSPath
    $displayName = $appProps.DisplayName
    if ($displayName) {
        Write-Host "Program: $displayName"
        foreach ($property in $appProps.PSObject.Properties) {
            $value = $property.Value
            if ($value -is [string] -and ($value -match '^[A-Za-z]:\\' -or $value -match '^".*:\\')) {
                Write-Host "  $($property.Name): $value"
            }
        }
        Write-Host ""

        [void]$appListBox.Items.Add($displayName)
        $appDisplayNameToRegistry[$displayName] = $appProps
    }
}

$uninstallButton.Add_Click({
    $selectedApps = $appListBox.CheckedItems
    foreach ($displayName in $selectedApps) {
        $appProps = $appDisplayNameToRegistry[$displayName]
        if ($appProps) {
            if (Get-Command -Name choco.exe -ErrorAction SilentlyContinue) {
                [System.Windows.Forms.MessageBox]::Show("Would uninstall: $($appProps.DisplayName)", "Uninstall", [System.Windows.Forms.MessageBoxButtons]::OK)
                Write-Host "Uninstalling: $($appProps.DisplayName)"
                choco uninstall $($appProps.DisplayName) -y
            } else {
                winget uninstall $($appProps.DisplayName) -e --silent
            }

            $searchFolders = @(
                "C:\Program Files",
                "C:\Program Files (x86)",
                "C:\Program Data",
                "$env:USERPROFILE\AppData\Local",
                "$env:USERPROFILE\AppData\Roaming",
                "$env:USERPROFILE\AppData\Local\Temp"
            )
            $displayName = $appProps.DisplayName
            foreach ($folder in $searchFolders) {
                if (Test-Path $folder) {
                    $matches = Get-ChildItem -Path $folder -Directory -ErrorAction SilentlyContinue | Where-Object {
                        $_.Name -like "*$displayName*"
                    }
                    foreach ($match in $matches) {
                        $msg = "Delete folder and all contents:`n$($match.FullName)?"
                        $result = [System.Windows.Forms.MessageBox]::Show($msg, "Cleanup", [System.Windows.Forms.MessageBoxButtons]::YesNo)
                        if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
                            Remove-Item -Path $match.FullName -Recurse -Force
                            Write-Host "Deleted: $($match.FullName)"
                        }
                    }
                }
            }
        }
    }
})

$mainForm.Controls.Add($appListBox)
$mainForm.Controls.Add($uninstallButton)
$mainForm.ShowDialog()
