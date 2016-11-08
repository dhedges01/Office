<#	
	.NOTES
	===========================================================================
	 Created with: 	SAPIEN Technologies, Inc., PowerShell Studio 2014 v4.1.62
	 Created on:   	7/8/2014 3:05 PM
	 Created by:   	Dustin Hedges
	 Organization: 	eBay Inc.
	 Filename:     	Get-MSOfficeProducts.PS1
	===========================================================================
	.DESCRIPTION
		Gathers all current Microsoft Office Products installed for an Office Upgrade.
		Using the -Uninstall switch will also attempt to uninstall any products
		    using MsiExec.exe and the Product Identifying Number.
#>


<#
	.SYNOPSIS
		A brief description of the Name function.

	.DESCRIPTION
		A detailed description of the Name function.

	.PARAMETER  ParameterA
		The description of a the ParameterA parameter.

	.PARAMETER  ParameterB
		The description of a the ParameterB parameter.

	.EXAMPLE
		PS C:\> Name -ParameterA 'One value' -ParameterB 32
		'This is the output'
		This example shows how to call the Name function with named parameters.

	.EXAMPLE
		PS C:\> Name 'One value' 32
		'This is the output'
		This example shows how to call the Name function with positional parameters.

	.INPUTS
		System.String,System.Int32

	.OUTPUTS
		System.String

	.NOTES
		For more information about advanced functions, call Get-Help with any
		of the topics in the links listed below.

	.LINK
		about_functions_advanced

	.LINK
		about_comment_based_help

	.LINK
		about_functions_advanced_parameters

	.LINK
		about_functions_advanced_methods
#>
[CmdletBinding()]
param (
	[Parameter(Position = 0, Mandatory = $false, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "The year 'Version' of the MS Office products you wish to query.  i.e. 2007, 2010, etc. Not setting this will query all product versions.")]
	[Int32[]]
	$Version,
	
	[Parameter(Position=0, Mandatory=$false,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage="Using this switch will uninstall ALL Microsoft Office products identified.")]
	[Switch]
	$Uninstall
)

<#
	.SYNOPSIS
		A brief description of the Write-Log -logPath $logPath -logFileName $logFileName function.

	.DESCRIPTION
		A detailed description of the Write-Log -logPath $logPath -logFileName $logFileName function.

	.PARAMETER  logPath
		A description of the Path parameter.

	.PARAMETER  LogFileName
		A description of the LogFileName parameter.

	.PARAMETER  Message
		A description of the Message parameter.

	.EXAMPLE
		PS C:\> Write-Log -logPath $logPath -logFileName $logFileName -Path 'Value1' -LogFileName 'Value2'
		'This is the output'
		This example shows how to call the Write-Log -logPath $logPath -logFileName $logFileName function with named parameters.

	.NOTES
		Additional information about the function or script.

#>
function Write-Log
{
	[CmdletBinding()]
	param
	(
		[Parameter(ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true,
				   Position = 1)]
		[System.String]
		$logPath = $(Split-Path $MyInvocation.MyCommand.Path),
		[Parameter(ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true,
				   Position = 2)]
		[System.String]
		$LogFileName = $($MyInvocation.MyCommand.Name -replace "ps1", "log"),
		[Parameter(Mandatory = $true,
				   ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true,
				   Position = 3)]
		[AllowEmptyString()]
		[System.String]
		$Message
	)
	
	$date = (Get-Date -Format u) -replace "Z", ""
	$logSeperator = $("-" * 50).ToString()
	$logHeader = @"
$logSeperator
***Script Information***
File Name: Get-MSOfficeProducts.PS1
Date Executed: $date
$logSeperator
"@
	
	# Get/Create Log File
	if (-not (Test-Path "$logPath\$LogFileName"))
	{
		$logFile = New-Item -Path $logPath -Name $LogFileName -ItemType File -Force
	}
	else
	{
		$logFile = Get-Item -Path "$logPath\$LogFileName"
	}
	
	# Initialize Log File and Write Header Information
	if (-not ($Script:logInit))
	{
		$logHeader | Out-File -FilePath $logFile.FullName -Append -Force
		$Script:logInit = $true
	}
	
	# Write Log Message
	$Message | Out-File -FilePath $logFile.FullName -Append -Force
	
}

# Connect to Microsoft Task Sequence Environment
$tsenv = New-Object -ComObject 'Microsoft.SMS.TSEnvironment' -ErrorAction 'SilentlyContinue'

# Setup Logging Variables
if ($tsenv)
{
	$Script:logPath = $tsenv.value("_SMSTSLOGPATH")
}
else
{
	$Script:logPath = "$env:WINDIR\eBay_Deployments"
}
$Script:logFileName = "Get-MSOfficeProducts.log"


# Build our MS Office Product Query so we can easily call it multiple times if necessary
if (-not ($Version))
{
	$msOfficeProductQuery = "Select * From Win32_Product Where Name Like 'Microsoft Office%' or Name Like 'Microsoft Visio%' or Name Like 'Microsoft Project%' or Name Like 'Microsoft Lync%' or Name Like 'Microsoft SharePoint Designer%'"
	Write-Log -logPath $logPath -logFileName $logFileName -Message "Checking All Microsoft Office Versions"
}
else
{
	$msOfficeProductQuery = "Select * From Win32_Product WHERE"
	for ($i = 0; $i -lt $Version.Count; $i++)
	{
		#Write-Log -logPath $logPath -logFileName $logFileName -Message "Checking Product Version : $($Version[$i])"
		if ($i -eq 0)
		{
			$msOfficeProductQuery += " Name Like 'Microsoft Office%$($Version[$i])%' OR Name Like 'Microsoft Visio%$($Version[$i])%' OR Name Like 'Microsoft Project%$($Version[$i])%' OR Name Like 'Microsoft Lync%$($Version[$i])%' OR Name Like 'Microsoft SharePoint Designer%$($Version[$i])%'"
		}
		else
		{
			$msOfficeProductQuery += " OR Name Like 'Microsoft Office%$($Version[$i])%' OR Name Like 'Microsoft Visio%$($Version[$i])%' OR Name Like 'Microsoft Project%$($Version[$i])%' OR Name Like 'Microsoft Lync%$($Version[$i])%' OR Name Like 'Microsoft SharePoint Designer%$($Version[$i])%'"
		}
	}
}


# Get all installed Office products matching our Version criteria
$msOfficeProductQuery += " Or Name = 'Microsoft Online Services Sign-in Assistant'"
Write-Log -logPath $logPath -logFileName $logFileName -Message $msOfficeProductQuery
$msOfficeProducts = Get-WmiObject -Query $msOfficeProductQuery

# Setup a hash table of Products and Product Codes for use later.
$hash = $null
$hash = @{ }

# Pull out specific products we want to deal with
Write-Log -logPath $logPath -logFileName $logFileName -Message "$($($msOfficeProducts| Where-Object { ($_.Name -notlike `"*MUI*`") -and ($_.Name -notlike `"*Server*`")}).Count) Total Products Identified"
foreach ($product in $msOfficeProducts | Sort | Where-Object { ($_.Name -notlike "*Server*") })
{
	switch -wildcard ($product.Name)
	{
		{ ($_ -like "Microsoft Office Professional*") -or ($_ -like "Microsoft Office Standard*") -or ($_ -like "Microsoft Office Small Business*") -or ($_ -like "Microsoft Office Enterprise*") -and ($_ -notmatch "MUI") } {
			Write-Log -logPath $logPath -LogFileName $logFileName -Message "Microsoft Office Suite Found : $($product.Caption) ($($product.IdentifyingNumber))"
			#$hash.Add($product.Caption, $product.IdentifyingNumber)
			$MSOfficeSuite = $product.IdentifyingNumber
            $MSOfficeSuiteVersion = $([version]$product.version).Major.ToString()
            $MSOfficeSuiteArch = (Get-ItemProperty -Path "HKLM:SOFTWARE\Microsoft\Office\$MSOfficeSuiteVersion.0\Outlook" -Name "Bitness" -ErrorAction SilentlyContinue).Bitness

			if ($tsenv)
			{
				Write-Log -logPath $logPath -LogFileName $logFileName -Message "Setting Task Sequence Variable ('MSOfficeSuite') = $MSOfficeSuiteVersion"
                $tsenv.Value("MsOfficeSuite") = $MSOfficeSuiteVersion 
                
                Write-Log -logPath $logPath -LogFileName $logFileName -Message "Setting Task Sequence Variable ('MSOfficeSuiteArch') = $MSOfficeSuiteArch"
				$tsenv.Value("MsOfficeSuiteArch") = $MSOfficeSuiteArch
			}
		}
		{ ($_ -like "Microsoft Office Project*") -or ($_ -like "Microsoft Project*") -and ($_ -notmatch "MUI") } {
			Write-Log -logPath $logPath -LogFileName $logFileName -Message "Microsoft Office Project Found : $($product.Caption) ($($product.IdentifyingNumber))"
			#$hash.Add($product.Caption, $product.IdentifyingNumber)
			if ($tsenv)
			{
				if ($product.Caption -like "*Professional*")
				{
					Write-Log -logPath $logPath -LogFileName $logFileName -Message "Setting Task Sequence Variable ('MSProjectPro') = $($([version]$product.version).Major.ToString())"
					$tsenv.Value("MSProjectPro") = $([version]$product.version).Major.ToString()
				}
				else
				{
					Write-Log -logPath $logPath -LogFileName $logFileName -Message "Setting Task Sequence Variable ('MSProjectStd') = $($([version]$product.version).Major.ToString())"
					$tsenv.Value("MSProjectStd") = $([version]$product.version).Major.ToString()
				}
			}
		}
		{ ($_ -like "Microsoft Office Visio*") -or ($_ -like "Microsoft Visio*") -and ($_ -notmatch "MUI") } {
			Write-Log -logPath $logPath -LogFileName $logFileName -Message "Microsoft Office Visio Found : $($product.Caption) ($($product.IdentifyingNumber))"
			#$hash.Add($product.Caption, $product.IdentifyingNumber)
			
            if ($tsenv)
			    {
                
                $visioVersion = $($([version]$product.version).Major.ToString())

                # Visio 2010 and newer have a way to check the edition through the automation object.
                # This is the most accurate way of determining the edition.  Specifically for Visio 2010,
                # this is the only method that works at the system level due to the way a single install with
                # multiple product keys.
                $visioEdition = -1
                if ($visioVersion -ge 14) {                    
                    # use the Visio automation object to pull the Visio edition for this computer
                    $visioApp = New-Object -ComObject Visio.Application
                    # 0=Standard, 1=Professional, 2=Premium (Visio 2010 only)
                    $visioEdition = $visioApp.CurrentEdition
                } 

                if ( ($product.Caption -like "*Professional*") -or ($visioEdition -eq 1) )
				{
					Write-Log -logPath $logPath -LogFileName $logFileName -Message "Setting Task Sequence Variable ('MSVisioPro') = $visioVersion"
					$tsenv.Value("MSVisioPro") = $visioVersion 
				}
				elseif ( ($product.Caption -like "*Premium*") -or ($visioEdition -eq 2) )
				{
					Write-Log -logPath $logPath -LogFileName $logFileName -Message "Setting Task Sequence Variable ('MSVisioPrm') = $visioVersion"
					$tsenv.Value("MSVisioPrm") = $visioVersion 
				}
                else
				{
					# anything other than the Professional edition is defaulted to Standard.
                    # Because Visio 2010 install defaulted to using the Premium product key unless a custom install was used,
                    # we'll assume that it was never meant to be used and default to Standard
                    Write-Log -logPath $logPath -LogFileName $logFileName -Message "Setting Task Sequence Variable ('MSVisioStd') = $visioVersion"
					$tsenv.Value("MSVisioStd") = $visioVersion 
				}                    
			}
		}
		{ ($_ -like "Microsoft Office SharePoint Designer*") -or ($_ -like "Microsoft SharePoint Designer*") -and ($_ -notmatch "MUI") } {
			Write-Log -logPath $logPath -LogFileName $logFileName -Message "Microsoft Office SharePoint Designer Found : $($product.Caption) ($($product.IdentifyingNumber))"
			#$hash.Add($product.Caption, $product.IdentifyingNumber)
			if ($tsenv)
			{
				Write-Log -logPath $logPath -LogFileName $logFileName -Message "Setting Task Sequence Variable ('MSSPDesigner') = $($([version]$product.version).Major.ToString())"
				$tsenv.Value("MsSpDesigner") = $([version]$product.version).Major.ToString()
			}
		}
		{ ($_ -like "*Lync*") -or ($_ -eq "Microsoft Office Communicator 2005") -or ($_ -eq "Microsoft Office Communicator 2007") -or ($_ -eq "Microsoft Office Communicator 2007 R2") -and ($_ -notmatch "MUI") } {
			Write-Log -logPath $logPath -LogFileName $logFileName -Message "Microsoft Lync Found : $($product.Caption) ($($product.IdentifyingNumber))"
			$hash.Add($product.Caption, $product.IdentifyingNumber)
		}
		{ ($_ -like "Microsoft Office Proofing Kit*") -and ($_ -notmatch "MUI") } {
			Write-Log -logPath $logPath -LogFileName $logFileName -Message "Microsoft Office Proofing Tools Found : $($product.Caption) ($($product.IdentifyingNumber))"
			#$hash.Add($product.Caption, $product.IdentifyingNumber)
			if ($tsenv)
			{
				Write-Log -logPath $logPath -LogFileName $logFileName -Message "Setting Task Sequence Variable ('MSProofKit') = $($([version]$product.version).Major.ToString())"
				$tsenv.Value("MSProofKit") = $([version]$product.version).Major.ToString()
			}
		}
		{ ($_ -like "Microsoft Office O MUI*") } {
			Write-Log -logPath $logPath -LogFileName $logFileName -Message "Microsoft Office Language Pack Found : $($product.Caption) ($($product.IdentifyingNumber)) ($($([version]$product.version).Major.ToString()))"
			$hash.Add($product.Caption, $product.IdentifyingNumber)
			switch ($_)
			{
				{ $_ -match "Chinese" } { if ($tsenv) { $tsenv.Value("MsLpChinese") = $([version]$product.version).Major.ToString() }; break; }
				{ $_ -match "Czech" } { if ($tsenv) { $tsenv.Value("MsLpCzech") = $([version]$product.version).Major.ToString() }; break; }
				{ $_ -match "Danish" } { if ($tsenv) {$tsenv.Value("MsLpDanish") = $([version]$product.version).Major.ToString() }; break; }
				{ $_ -match "Dutch" } { if ($tsenv) {$tsenv.Value("MsLpDutch") = $([version]$product.version).Major.ToString() }; break; }
				{ $_ -match "French" } { if ($tsenv) {$tsenv.Value("MsLpFrench") = $([version]$product.version).Major.ToString() }; break; }
				{ $_ -match "German" } { if ($tsenv) {$tsenv.Value("MsLpGerman") = $([version]$product.version).Major.ToString() }; break; }
				{ $_ -match "Hebrew" } { if ($tsenv) {$tsenv.Value("MsLpHebrew") = $([version]$product.version).Major.ToString() }; break; }
				{ $_ -match "Italian" } { if ($tsenv) {$tsenv.Value("MsLpItalian") = $([version]$product.version).Major.ToString() }; break; }
				{ $_ -match "Korean" } { if ($tsenv) {$tsenv.Value("MsLpKorean") = $([version]$product.version).Major.ToString() }; break; }
				{ $_ -match "Polish" } { if ($tsenv) {$tsenv.Value("MsLpPolish") = $([version]$product.version).Major.ToString() }; break; }
				{ $_ -match "Russian" } { if ($tsenv) {$tsenv.Value("MsLpRussian") = $([version]$product.version).Major.ToString() }; break; }
				{ $_ -match "Spanish" } { if ($tsenv) {$tsenv.Value("MsLpSpanish") = $([version]$product.version).Major.ToString() }; break; }
				{ $_ -match "Swedish" } { if ($tsenv) {$tsenv.Value("MsLpSwedish") = $([version]$product.version).Major.ToString() }; break; }
			}
		}
		{ ($_ -eq 'Microsoft Online Services Sign-in Assistant') }{
			Write-Log -logPath $logPath -LogFileName $logFileName -Message "Microsoft Online Services Sign-in Assistant Found : ($($product.IdentifyingNumber)) ($($([version]$product.version).Major.ToString()))"
			$hash.Add($product.Caption, $product.IdentifyingNumber)
		}
		default
		{
			# if its not explicitely defined above we want to skip over it
			Write-Log -logPath $logPath -LogFileName $logFileName -Message "Skipping Product : $($product.Caption) ($($product.IdentifyingNumber))"
		}
	}
}

# Parse each identified application from our "scrubbed" inital query
foreach ($key in $hash.GetEnumerator())
{
	if (-not ($key.Value -eq $MSOfficeSuite))
	{
		# Uninstall all Non-Suite Software
		if ($Uninstall)
		{
			$result = Start-Process "MsiExec.exe" -ArgumentList "/X `"$($key.Value)`" /qn /norestart" -NoNewWindow -Wait -PassThru
			do
			{
				Write-Log -logPath $logPath -LogFileName $logFileName -Message "Uninstalling Product : $($key.Name) ($($key.Value))"
				Start-Sleep -Seconds 30
			}
			while (Get-Process -Id $result.Id -ErrorAction SilentlyContinue)
			Write-Log -logPath $logPath -LogFileName $logFileName -Message "Installer Exit Code : $($result.ExitCode)"
		}
	}
}

# Cleanup Office SharePoint Workspace and other Office Suite components
<#
if ($MSOfficeSuite -and $Uninstall)
{
	$result = Start-Process "MsiExec.exe" -ArgumentList "/X `"$($key.Value)`" /qn /norestart" -NoNewWindow -Wait -PassThru
	do
	{
		Write-Log -logPath $logPath -LogFileName $logFileName -Message "Cleaning up Microsoft Office Suite, SharePoint Workspace and other Shared Components"
		Start-Sleep -Seconds 30
	}
	while (Get-Process -Id $result.Id -ErrorAction SilentlyContinue)
	Write-Log -logPath $logPath -LogFileName $logFileName -Message "Installer Exit Code : $($result.ExitCode)"
}
#>