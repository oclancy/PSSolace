using namespace SolaceSystems.Solclient.Messaging
using namespace Proquote.TechnologyPlatform.Service.Endpoints.Solace.Messaging

Add-Type -AssemblyName "${PSScriptRoot}\\SolaceSystems.Solclient.Messaging.dll" -PassThru
Add-Type -AssemblyName "${PSScriptRoot}\\Newtonsoft.Json.dll" -PassThru
Add-Type -AssemblyName "${PSScriptRoot}\\Firmus.Messages.dll" -PassThru
Add-Type -AssemblyName "${PSScriptRoot}\\Protobuf.dll" -PassThru

function Send-SolaceMessageToTopic{

    [CmdletBinding()]
    param (
        [ISession]
        $Session,
        [IFirmusMessage]
        $Message
    )

    $serialiser = New-Object "Serialiser<FirmusMessage>" #TBD - Make generic....

    [IMessage] $solacemessage = [ContextFactory]::Instance.CreateMessage()

    $solacemessage.Destination = [ContextFactory]::Instance.CreateTopic( $Message.Destination.Name );

    $solacemessage.DeliveryMode = [MessageDeliveryMode]::Persistent
    $solacemessage.BinaryAttachment = $serialiser.Serialise($Message)

    Write-Host "Sending message to topic {$Topic.Name}..."
    return $session.Send($solacemessage)
}

function New-PriceSolaceMessage{

    [CmdletBinding()]
    param (
        [string]
        $Type,
        [string]
        $Symbol,
        [string]
        $Isin,
        [string]
        $Exchange,
        [double]
        $Price,
        [double]
        $Size,
        [TradingPhase]
        $TradingPhase
    )

    $newprice = New-Object $Type
    $newprice.StockId = "$Isin/$Exchange/$Symbol"
    $newprice.TouchSize = $Size
    $newprice.TouchPrice = $Price
    $newprice.Currency = $Currency
    $newprice.TradingPhase = $TradingPhase

    return $newprice
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

    Write-Host "Received session event $( $SessionEventArgs.ToString )."
}

function Set-Price
{
    [CmdletBinding()]
    param (
        [string]
        $SolaceHost,
        [string]
        $VpnName,
        [string]
        $User,
        [string]
        $Password,
        [string]
        $Symbol,
        [string]
        $Isin,
        [string]
        $Exchange,
        [double]
        $Price,
        [double]
        $Size,
        [TradingPhase]
        $TradingPhase = [TradingPhase]::RegularTrading
    )

    if ($args.Length -lt 3)
    {
        Write-Host "Usage: TopicPublisher <host> <username>@<vpnname> <password>"
        Environment.Exit(1);
    }

    try{
        $lastPx = New-PriceSolaceMessage "StockPriceMessage" $Symbol $Isin $Exchange $Price $Size $TradingPhase
        $session = New-Session $SolaceHost $VpnName $User $Password
        Send-SolaceMessage $session $lastPx
    }
    catch
    {
        Write-Error "Exception thrown: {$_.Exception.Message}";
        Write-Error "$([ContextFactory]::GetLastSDKErrorInfo)"
    }
    finally{
        Cleanup-Session
    }
}

function New-Session{

  [CmdletBinding()]

    param (
        [string]
        $SolaceHost,
        [string]
        $VpnName,
        [string]
        $User,
        [string]
        $Password
    )

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

        $sessionProps.Host = $SolaceHost
        $sessionProps.VPNName = $VpnName
        $sessionProps.UserName = $User
        $sessionProps.Password = $Password
        $sessionProps.ReconnectRetries = 1 # DefaultReconnectRetries

        $session = $context.CreateSession($sessionProps, $null, $HandleSessionEvent)

        $returnCode = $session.Connect();

        if ($returnCode -eq [ReturnCode]::SOLCLIENT_OK)
        {
            Write-Host "Session successfully connected."
        }
        else
        {
            Write-Error "Error connecting, return code: $returnCode"
        }
    }
    catch
    {
        Write-Error "Exception thrown: {$_.Exception.Message}";
        Write-Error "$([ContextFactory]::GetLastSDKErrorInfo)"
        throw
    }
}

function Cleanup-Session{
    try
    {
        # Dispose Solace Systems Messaging API
        [ContextFactory]::Instance.Cleanup();
    }
    catch
    {
        Write-Error "Exception thrown: {$_.Exception.Message}";
        Write-Error "$([ContextFactory]::GetLastSDKErrorInfo)"
    }
    finally
    {
        Write-Host "Finished."
    }

}

Set-Price "192.168.1.136" "SOL1" "admin" "admin" "BARC" "GB00B" "L" 123.0 456.0
