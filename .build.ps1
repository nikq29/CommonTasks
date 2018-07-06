[cmdletBinding()]
Param (
    [Parameter(Position = 0)]
    $Tasks,

    [switch]
    $ResolveDependency,

    [String]
    $BuildOutput = "BuildOutput",

    [String[]]
    $GalleryRepository,

    [Uri]
    $GalleryProxy,

    [Switch]
    $ForceEnvironmentVariables = [switch]$true,

    $MergeList = @('enum*', [PSCustomObject]@{Name = 'class*'; order = {(Import-PowerShellDataFile .\SampleModule\Classes\classes.psd1).order.indexOf($_.BaseName)}}, 'priv*', 'pub*'),
    
    $CodeCoverageThreshold = 90
)

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12
$buildModulesPath = Join-Path -Path $BuildOutput -ChildPath Modules
$ProjectPath = $PSScriptRoot

if (-not (Test-Path -Path $buildModulesPath)) {
    $null = mkdir -Path $buildModulesPath -Force
}

if ($buildModulesPath -notin ($Env:PSModulePath -split ';')) {
    $env:PSModulePath = "$buildModulesPath;$Env:PSModulePath"
}

if (-not (Get-Module -Name InvokeBuild -ListAvailable) -and -not $ResolveDependency) {
    Write-Error "Requirements are missing. Please call the script again with the switch 'ResolveDependency'"
    return
}

if ($ResolveDependency) {
    . $PSScriptRoot/.build/BuildHelpers/Resolve-Dependency.ps1
    Resolve-Dependency
}

Get-ChildItem -Path "$PSScriptRoot/.build/" -Recurse -Include *.ps1 |
    ForEach-Object {
    Write-Verbose "Importing file $($_.BaseName)"
    try {
        . $_.FullName
    }
    catch { }
}

if ($MyInvocation.ScriptName -notlike '*Invoke-Build.ps1') {
    if ($ResolveDependency -or $PSBoundParameters['ResolveDependency']) {
        $PSBoundParameters.Remove('ResolveDependency')
    }

    if ($Help) {
        Invoke-Build ?
    }
    else {
        Invoke-Build -Tasks $Tasks -File $MyInvocation.MyCommand.Path @PSBoundParameters
    }

    return
}
task . Clean_BuildOutput

#task PSModulePath_BuildModules {
#    if (!([System.IO.Path]::IsPathRooted($BuildOutput)))
#    {
#        $BuildOutput = Join-Path -Path $ProjectPath -ChildPath $BuildOutput
#    }
#
#    $configurationPath = Join-Path -Path $ProjectPath -ChildPath $ConfigurationsFolder
#    $resourcePath = Join-Path -Path $ProjectPath -ChildPath $ResourcesFolder
#    $buildModulesPath = Join-Path -Path $BuildOutput -ChildPath Modules
#        
#    Set-PSModulePath -ModuleToLeaveLoaded $ModuleToLeaveLoaded -PathsToSet @($configurationPath, $resourcePath, $buildModulesPath)
#}
#
#task . Clean_BuildOutput
#
#task Download_All_Dependencies -if ($DownloadResourcesAndConfigurations -or $Tasks -contains 'Download_All_Dependencies') Download_DSC_Configurations, Download_DSC_Resources -Before PSModulePath_BuildModules

#task Download_DSC_Resources {
#    $PSDependResourceDefinition = "$ProjectPath\PSDepend.DSC_Resources.psd1"
#    if (Test-Path $PSDependResourceDefinition) {
#        Invoke-PSDepend -Path $PSDependResourceDefinition -Confirm:$false -Target $resourcePath
#    }
#}
#
#task Download_DSC_Configurations {
#    $PSDependConfigurationDefinition = "$ProjectPath\PSDepend.DSC_Configurations.psd1"
#    if (Test-Path $PSDependConfigurationDefinition) {
#        Write-Build Green 'Pull dependencies from PSDepend.DSC_Configurations.psd1'
#        Invoke-PSDepend -Path $PSDependConfigurationDefinition -Confirm:$false -Target $configurationPath
#    }
#}
#
#task Clean_DSC_Resources_Folder {
#    Get-ChildItem -Path "$ResourcesFolder" -Recurse | Remove-Item -Force -Recurse -Exclude README.md
#}
#
#task Clean_DSC_Configurations_Folder {
#    Get-ChildItem -Path "$ConfigurationsFolder" -Recurse | Remove-Item -Force -Recurse -Exclude README.md
#}
#
#task Zip_Modules_For_Pull_Server {
#    if (!([System.IO.Path]::IsPathRooted($buildOutput))) {
#        $BuildOutput = Join-Path $PSScriptRoot -ChildPath $BuildOutput
#    }
#    Import-Module DscBuildHelpers -ErrorAction Stop
#    Get-ModuleFromfolder -ModuleFolder (Join-Path $ProjectPath -ChildPath $ResourcesFolder) |
#        Compress-DscResourceModule -DscBuildOutputModules (Join-Path $BuildOutput -ChildPath 'DscModules') -Verbose:$false 4>$null
#}
#
#task Test_ConfigData {
#    if (!(Test-Path -Path $testsPath)) {
#        Write-Build Yellow "Path for tests '$testsPath' does not exist"
#        return
#    }
#    if (!([System.IO.Path]::IsPathRooted($BuildOutput))) {
#        $BuildOutput = Join-Path -Path $PSScriptRoot -ChildPath $BuildOutput
#    }
#    $testResultsPath = Join-Path -Path $BuildOutput -ChildPath TestResults.xml
#    $testResults = Invoke-Pester -Script $testsPath -PassThru -OutputFile $testResultsPath -OutputFormat NUnitXml
#
#    assert ($testResults.FailedCount -eq 0)
#}