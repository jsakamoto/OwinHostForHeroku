param($installPath, $toolsPath, $package, $project)
$solutionDir = [System.IO.Path]::Combine($installPath, "..\..\")
$solutionDir = [System.IO.Path]::GetFullPath($solutionDir)

# Uninstall "Procfile".
$sourceProcfilePath = Join-Path $toolsPath "Procfile"
$destinationProcfilePath = Join-Path $solutionDir "Procfile"
if ((Test-Path -PathType Leaf $destinationProcfilePath) -eq $true) {
	$sourceProcfileContent = cat $sourceProcfilePath
	$destinationProcfileContent = cat $destinationProcfilePath
	if ($sourceProcfileContent -ceq $destinationProcfileContent) {

		$solution = Get-Interface $dte.Solution ([EnvDTE80.Solution2])
		$solutionFolder = $solution.Projects | where { $_.Name -eq "Solution Items"}
		if ($solutionFolder -ne $null) {
			$projItemProcfile = $solutionFolder.ProjectItems | where { $_.Name -eq "Procfile" }
			if ($projItemProcfile -ne $null) {
				$projItemProcfile.Delete()
				del $destinationProcfilePath
			}
			if ($solutionFolder.ProjectItems.Count -eq 0) {
				$dte.Solution.Remove($solutionFolder)
			}
		}
	}
}

# Uninstall custom Web server provider.
$serverProvider = $dte.GetObject("CustomWebServerProvider")
if ($serverProvider -eq $null)
{
    return; # Only supported on VS 2013
}
$servers = $serverProvider.GetCustomServers($project.Name)
if ($servers -eq $null)
{
    return; # Not a WAP project
}
$server = $servers.GetWebServer('OwinHost for Heroku')
if ($server -ne $null)
{
    Add-Type -AssemblyName Microsoft.VisualBasic
    $prompt = [Microsoft.VisualBasic.Interaction]::MsgBox("Remove custom server settings?",'YesNo,Question', "Uninstalling Custom Server")
    if ($prompt -eq [Microsoft.VisualBasic.MsgBoxResult]::Yes)
    {
        $servers.RemoveWebServer('OwinHost for Heroku');
    }
}
