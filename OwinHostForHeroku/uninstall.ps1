param($installPath, $toolsPath, $package, $project)
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
        $servers.RemoveWebServer('OwinHost fro Heroku');
    }
}
