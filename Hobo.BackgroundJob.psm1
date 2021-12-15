#Job Name Structure: [ModuleName]:[Category]:[Name]
$jobNameRegex = "^.*:.*:.*"

function Get-PsBackgroundJobTaskName
{
    param(
        [parameter(Mandatory=$true)]
        [string]$Name,
        [parameter(Mandatory=$true)]
        [string]$Module,
        [parameter(Mandatory=$true)]
        [string]$Category
    )

    return "$Module`:$Category`:$Name"
}

function Get-PsBackgroundJobTaskInfo
{
    param(
        [string]$JobName
    )

    $splitName = $JobObject.Name -split ':'
    $splitComponentCount = $splitName | measure | select -ExpandProperty Count
    if ($splitComponentCount -eq 3)
    {
        New-Object psobject -Property @{ Module = $splitName[0] ; Category = $splitName[1] ; Name = $splitName[2] }
    }
    else
    {
        Write-Error "Received malformed job name: $JobName.`n`nExpectedComponents: 3`nTotal components: $splitComponenetCount"
    }
}

class PsBackgroundJob
{
    [int]$Id
    [string]$Name
    [string]$Module
    [string]$Category
    [string]$Status
    [datetime]$StartTime
    hidden $JobObject

    PsBackgroundJob($JobObject)
    {
        $this.Id = $JobObject.Id
        $this.Status = $JobObject.State
        $this.StartTime = $JobObject.PSBeginTime

        $jobInfo = Get-PsBackgroundJobTaskInfo $JobObject.Name
        $this.Module = $jobInfo.Module
        $this.Category = $jobInfo.Category
        $this.Name = $jobInfo.Name

        $this.JobObject = $JobObject
    }
}

function Get-PSBackgroundJob
{
    [cmdletbinding(DefaultParameterSetName="All")]
    param(
        [Parameter(Mandatory=$true, ParameterSetName = 'PsBackgroundJob')]
        [PsBackgroundJob]$PsBackgroundJob,
        [Parameter(Mandatory=$true, ParameterSetName = 'Id')]
        [int]$Id,
        [Parameter(ParameterSetName = 'All')]
        [switch]$All,

        [Parameter(ParameterSetName = 'PsBackgroundJob')]
        [Parameter(ParameterSetName = 'Id')]
        [Parameter(ParameterSetName = 'All')]
        [ValidateNotNullOrEmpty()]
        [string]$Name = '*',

        [Parameter(ParameterSetName = 'PsBackgroundJob')]
        [Parameter(ParameterSetName = 'Id')]
        [Parameter(ParameterSetName = 'All')]
        [ValidateNotNullOrEmpty()]
        [string]$Module = '*',

        [Parameter(ParameterSetName = 'PsBackgroundJob')]
        [Parameter(ParameterSetName = 'Id')]
        [Parameter(ParameterSetName = 'All')]
        [ValidateNotNullOrEmpty()]
        [string]$Category = '*'
    )

    begin
    {
        #if ($PsBackgroundJob -and $Id) { throw "PSBackgroundJob and Id parameters both defined.  Only one of those parameters may be defined per command." }
        if ($PsBackgroundJob) { $Id = $PsBackgroundJob.Id }
    }

    process
    {
        if ($Id) { [PsBackgroundJob]::new((Get-Job -Id $Id -ErrorAction Stop)) }
        else
        {
            Get-Job |
                where { $_.Name -match $jobNameRegex } |
                foreach { [PsBackgroundJob]::new($_) } |
                    where { $_.Name -like $Name } |
                    where { $_.Module -like $Module } |
                    where { $_.Category -like $Category }
        }
    }
}

function Start-PsBackgroundJob
{
    param(
        [parameter(Mandatory=$true)]
        [string]$Name,
        [parameter(Mandatory=$true)]
        [string]$Module,
        [parameter(Mandatory=$true)]
        [string]$Category,
        [parameter(Mandatory=$true)]
        [scriptblock]$ScriptBlock,
        [object[]]$ArgumentList,
        [switch]$PassThru
    )

    begin
    {
        $param_StartJob = @{
            Name = Get-PsBackgroundJobTaskName -Name $Name -Module $Module -Category $Category
            ScriptBlock = $ScriptBlock
        }

        if ($ArgumentList) { $param_StartJob.Add('ArgumentList', $ArgumentList) }
    }

    process
    {
        $jobObject = Start-Job @param_StartJob
        if ($PassThru) { Write-Output ([PsBackgroundJob]::new($jobObject)) }
    }
}

function Stop-PsBackgroundJob
{
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, ParameterSetName='PsBackgroundJob')]
        [PsBackgroundJob[]]$PsBackgroundJob,
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, ParameterSetName='Id')]
        [int[]]$Id,

        [Parameter(ParameterSetName = 'PsBackgroundJob')]
        [Parameter(ParameterSetName = 'Id')]
        [switch]$Force
    )

    begin
    {
        if ($Id) { $PsBackgroundJob = $Id | foreach { Get-PSBackgroundJob -Id $_ } }
    }

    process
    {
        foreach ($job in $PsBackgroundJob) { $job.JobObject | Stop-Job -ErrorAction Continue -Force:$Force }
    }
}

function Receive-PsBackgroundJob
{
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, ParameterSetName='PsBackgroundJob')]
        [PsBackgroundJob[]]$PsBackgroundJob,
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, ParameterSetName='Id')]
        [int[]]$Id,

        [Parameter(ParameterSetName = 'PsBackgroundJob')]
        [Parameter(ParameterSetName = 'Id')]
        [switch]$Force
    )

    begin
    {
        if ($Id) { $PsBackgroundJob = $Id | foreach { Get-PSBackgroundJob -Id $_ } }
    }

    process
    {
        foreach ($job in $PsBackgroundJob) { $job.JobObject | Receive-Job -ErrorAction Continue -Force:$Force }
    }
}

function Remove-PsBackgroundJob
{
    [cmdletbinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'PsBackgroundJob')]
        [PsBackgroundJob[]]$PsBackgroundJob,
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'Id')]
        [int[]]$Id,

        [Parameter(ParameterSetName = 'PsBackgroundJob')]
        [Parameter(ParameterSetName = 'Id')]
        [switch]$Force
    )

    begin
    {
        if ($Id) { $PsBackgroundJob = $Id | foreach { Get-PSBackgroundJob -Id $_ } }
    }

    process
    {
        foreach ($job in $PsBackgroundJob) { $job.JobObject | Remove-Job -ErrorAction Continue -Force:$Force }
    }
}
