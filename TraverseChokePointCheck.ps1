# When should I check for traffic? 
# Paramater of scheduled task or chron job.

# For how long should I report traffic conditions that exceed the threshold?
# Paramater of scheduled task or chron job.

# =============== <SETTINGS_NOT_STORED_IN_GIT> ===============
# Read in the values from the INI not stored in GIT.
$INI = "TraverseChokePointCheck.ini"
# If the INI doesn't exist, create it from the template INI.
If(!(Test-Path $INI)) { Copy ("TEMPLATE" + $INI) $INI }
Get-Content $INI | foreach-object -begin {$h=@{}} -process { $k = [regex]::split($_,'='); if(($k[0].CompareTo("") -ne 0) -and ($k[0].StartsWith("[") -ne $True) -and ($k[0].StartsWith("#") -ne $True)) { $h.Add($k[0], $k[1]) } }
# Email settings
$Srvr = $h.'$Srvr'
$FromUsr = $h.'$FromUsr'
$FromEmail = $h.'$FromEmail'
$FromPwd = $h.'$FromPwd'
$ToEmail = $h.'$ToEmail'
$Subj = $h.'$Subj'

# Google Maps API key
$Key = $h.'$Key'
# =============== </SETTINGS_NOT_STORED_IN_GIT> ===============


# Should I report choke point over or under the threshold?
$UnderThreshold = $true

# Threshold in seconds
$Threshold = (9*60)

$URI = "https://maps.googleapis.com/maps/api/directions/"

$Output = "json" # (or xml)

# Define the choke points starting and ending coordinates.
# Click on google maps to find these if you do not know them.
# Values should be URL encoded (space is '+').
$Origin = "33.903519,+-84.459652"
$Destination = "33.927579,+-84.461067"

$DepartureTime = "now"

$TrafficModel = "best_guess"

# Assemble the URI for a get method.
$URI = $URI + $Output + "?origin=" +$Origin+ "&destination=" +$Destination+ "&key=" +$Key+ "&departure_time=" +$DepartureTime+ "&traffic_model=" + $TrafficModel

# Make sure the URI does not exceed 2000 in length.
If(2001>$URI.Length) { "Error: your URI is too long. Sorry, I can not help you fix that because I was rushed to complete this quickly and used the 'get' method rather than posting the data. Gift me some bitcoin value and I will correct it!" }
Else
{
    $Proxy = Invoke-RestMethod -Uri $URI -Method Get
    #$Proxy.routes[0].legs[0].duration_in_traffic.text

    If(!($Proxy.status.Equals("OK"))){ "Error: something happened while trying to get the data from Google. Google returned status " +$Proxy.status+ ". Maybe try again?" }
    Else
    {
        $Body = ""
        $ConditionsSatisfied = $false

        # Go through all the routes.
        ForEach ($route in $Proxy.routes)
        {
            ForEach ($leg in $route.legs)
            {
                # Were conditions satisfied?
                If( ($leg.duration_in_traffic.value -lt $Threshold) -eq $UnderThreshold )
                {
                    $ConditionsSatisfied = $true 
                    $Body = $Body + "<div style='background-color:yellow'>Google estimates the time to get through the chokepoint using the following route is " + $leg.duration_in_traffic.text + ".</div>"
                    ForEach ($step in $leg.steps)
                    {
                        $Body = $Body + "<div>" +$step.html_instructions+ "</div>"
                    }
                }
                "Message: Currently reported time through chokepoint is " + $leg.duration_in_traffic.text + "."
            }
        }

        # Notify if conditions satisfied
        If($ConditionsSatisfied)
        {
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
        $FromPwd = ConvertTo-SecureString $FromPwd -AsPlainText -Force
        $Cred = New-Object -Typename System.Management.Automation.PSCredential -ArgumentList $FromUsr, $FromPwd
        Send-Mailmessage -smtpServer $Srvr -From $FromEmail -To $ToEmail -Subject $Subj -BodyAsHtml -Body $Body -Credential $Cred  -UseSsl
        }
        Else
        {
            "Message: Conditions not met to trigger email."
        }
    }
}
