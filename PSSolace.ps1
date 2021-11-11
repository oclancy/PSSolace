using namespace SolaceSystems.Solclient.Messaging

Add-Type -AssemblyName "${PSScriptRoot}\\SolaceSystems.Solclient.Messaging.dll" -PassThru

function SendMessage {
    
    [CmdletBinding()]
    param (
        [Parameter()]
        [ISession]
        $Session,
        [Parameter()]
        [string]
        $Destination,
        [Parameter()]
        [string]
        $Message
    )

    [IMessage] $message = [ContextFactory]::Instance.CreateMessage()

    $message.top = $Destination;
    $message.DeliveryMode = [MessageDeliveryMode]::NonPersistent;
    $message.BinaryAttachment = Encoding.ASCII.GetBytes($Message);

    Write-Host "Sending message to queue {$Destination}..."
    $returnCode = $Session.Send($message);

}

function HandleSessonEvent
{

    [CmdletBinding()]
    param (
        [Parameter()]
        [System.Object]
        $Source,
        [Parameter()]
        [SessionEventArgs]
        $SessionEventArgs
    )

    Write-Host "Received session event $( SessionEventArgs.ToString )."
}



if ($args.Length -lt 3)
{
    Write-Host "Usage: TopicPublisher <host> <username>@<vpnname> <password>"
    Environment.Exit(1);
}

$split = $args[1].Split('@');
if ($split.Length -ne 2)
{
    Write-Host "Usage: TopicPublisher <host> <username>@<vpnname> <password>";
    [System.Environment]::Exit(1);
}

$hostname = $args[0]; # Solace messaging router host name or IP address
$vpnname = $split[1];
$username = $split[0];
$password = $args[2];

# Initialize Solace Systems Messaging API with logging to console at Warning level
$cfp = New-Object -TypeName "ContextFactoryProperties"
$cfp.SolClientLogLevel = [SolLogLevel]::Warning

$cfp.LogToConsoleError();
[ContextFactory]::Instance.Init($cfp);

try
{
    # Context must be created first
    $ctxtProps = New-Object -TypeName "ContextProperties"
    $context = [ContextFactory]::Instance.CreateContext($ctxtProps, $null)

    $sessionProps = New-Object -TypeName "SessionProperties"

    $sessionProps.Host = $hostname
    $sessionProps.VPNName = $vpnname
    $sessionProps.UserName = $username
    $sessionProps.Password = $password
    $sessionProps.ReconnectRetries = 1 # DefaultReconnectRetries

    $session = $context.CreateSession($sessionProps, $null, $HandleSessionEvent)

    $returnCode = $session.Connect();

    if ($returnCode -eq [ReturnCode]::SOLCLIENT_OK)
    {

        $topic = [ContextFactory]::Instance.CreateTopic("TopicA");
        if ($session.Subscribe($topic, $true) == [ReturnCode]::SOLCLIENT_OK)
        {
            Write-Host "Successfully added topic subscription";
        }

        Write-Host "Session successfully connected."

        SendMessage($session, "topic1", "testMsg");
    }
    else
    {
        Write-Error "Error connecting, return code: $returnCode"
    }
}
catch
{
    Write-Error "Exception thrown: {$_.Message}";
    Write-Error "$([ContextFactory]::GetLastSDKErrorInfo)"
}
finally
{
    # Dispose Solace Systems Messaging API
    [ContextFactory]::Instance.Cleanup();
}
Write-Host "Finished."