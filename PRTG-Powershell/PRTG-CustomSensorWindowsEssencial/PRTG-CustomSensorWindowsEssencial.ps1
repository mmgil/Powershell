<#
.SYNOPSIS
    .SCRIPT PARA OBTER DADOS ESSENCIAIS DE DESEMPENHO E DISPONIBILIDADE DA MAQUINA PARA SEREM ARMAZENADAS NO SISTEMA PRTG NETWORK MONITOR
.DESCRIPTION
    .SCRIPT PARA OBTER DADOS ESSENCIAIS DE DESEMPENHO E DISPONIBILIDADE DA MAQUINA PARA SEREM ARMAZENADAS NO SISTEMA PRTG NETWORK MONITOR
.PARAMETER NomeDoComputador
    .Digite o nome FQDN do computador (certifique-se que esse nome resolva a partir do host que executa o script) ou então o endereço IP (tenha certeza queo host que executa o script tem acesso à esse computador destino)
.PARAMETER NomeDeUsuario
    .Nome de Usuario que tem acesso administrativo no computador destino
.PARAMETER Senha
    .A Senha do usuário acima. Para manter o sigilo dessas informações usamos as variaveis do PRTG Network Monitor conforme exemplos a seguir
.EXAMPLE
    C:\PS>& '.\PRTG-CustomSensorWindowsEssencial.ps1' -NomeDoComputador %host -NomeDeUsuario "%windowsdomain\%windowsuser" -Senha "%windowspassword"
    
.NOTES
    Author: Moises de Matos Gil (moises@mmgil.com.br)
    Date:   Março 07, 2017

    Julho 14, 2018 - Esse script não consegue obter as métricas de Rede do Windows Server 2008 R2.
    Julho 14, 2018 - Alterado o metodo de conexão de PSSession para CIMSession, para melhorar a performance
    Julho 14, 2018 - Script Adaptado para suportar Nano Server 2016.
    Março 08, 2017 - Melhoria de desempenho, realiza a coleta através de uma única SESSION de Powershell
    Março 07, 2017 - Criado a Primeira Versão desse SCRIPT
#>

param(
# PARAMETROS
    [Parameter( Mandatory = $True, ValueFromPipeline = $True, position = 0, HelpMessage = "Digite o nome do Computador" )]
    [string]$NomeDoComputador,
    [Parameter( Mandatory = $True, ValueFromPipeline = $True, position = 0, HelpMessage = "Digite o Nome de Usuario" )]
    [string]$NomeDeUsuario,
    [Parameter( Mandatory = $True, ValueFromPipeline = $True, position = 0, HelpMessage = "Digite a Senha" )]
    [string]$Senha
)

#######################################
function New-GenerateCredentials(){

    # Generate Credentials if we're not checking localhost
    if((($env:COMPUTERNAME) -ne $NomeDoComputador)){

        # Generate Credentials Object first
        $SecPasswd  = ConvertTo-SecureString $Senha -AsPlainText -Force
        $Credentials= New-Object System.Management.Automation.PSCredential ($NomeDeUsuario, $SecPasswd)
        return $Credentials

    }

    # otherwise return false
    else{ return "false" }
}  

$Credentials = (New-GenerateCredentials);

# DECLARANDO VARÍAVEIS QUE SERÃO USADAS
$result = @()

# ABRINDO UMA SESSÃO CIMSESSION AO INVES DE PSSESSION POR QUESTOES DE PERFORMANCE
$CimSession = New-CimSession -ComputerName $NomeDoComputador -Credential $Credentials

# OBTER INFORMAÇÕES ATRAVES DE WMI REMOTAMENTE, SEM NECESSIDADE DE CRIAR UMA PSSESSION PARA ACESSAR O SERVIDOR

## CARGA DE CPU
#$CPULoad = Get-WmiObject -Class win32_processor -ComputerName $NomeDoComputador -Credential $Credentials | Select DeviceID, Name, SocketDesignation, LoadPercentage
$CPULoad = Get-CimInstance -ClassName win32_processor -CimSession $CimSession | Select-Object DeviceID, Name, SocketDesignation, LoadPercentage

## CARGA DE MEMORIA
$memory = Get-CimInstance -ClassName win32_OperatingSystem -CimSession $CimSession -ErrorAction SilentlyContinue
$memory = (($memory.TotalVisibleMemorySize - $memory.FreePhysicalMemory) / $memory.TotalVisibleMemorySize) * 100

## ESPAÇO EM DISCO
$disksSpace = Get-CimInstance -ClassName Win32_LogicalDisk -CimSession $CimSession -Filter "DriveType=3"

$diskInfo = @()

foreach ($disk in $disksSpace){
    $porcentagem = (($disk.Size - $disk.FreeSpace) / $disk.Size) * 100
    
    $tempDiskSpace = New-Object -Type PSObject
    
    $tempDiskSpace = [PSCustomObject] @{
        DeviceID = $disk.DeviceID
        FreeSpace = $disk.FreeSpace
        Size = $disk.Size
        Porcentagem = [int]$porcentagem
    }
    
    $diskInfo += $tempDiskSpace
}
#return ($diskInfo | sort Porcentagem -Descending)

## DESEMPENHO DE DISCO
$disksPerformance = Get-CimInstance -ClassName Win32_PerfFormattedData_PerfDisk_PhysicalDisk -CimSession $CimSession | Where-Object {$_.Name -ne "_Total"} | Select-Object SplitIOPerSec,  AvgDiskQueueLength, CurrentDiskQueueLength, PercentIdleTime

## DESEMPENHO DE REDE
$getInterfaceIndex = (Get-NetIPAddress -CimSession $CimSession | Where-Object {($_.IpAddress -like "10.*") -or ($_.IpAddress -like "192.168.*") -or ($_.IpAddress -like "172.*") }).InterfaceIndex
$getInterfaceIndex = $getInterfaceIndex | Select-Object -Unique

$redeInfo = @()

foreach($InterfaceIndex in $getInterfaceIndex) {

    $getInterfaceDescription = (Get-NetAdapter -CimSession $CimSession -InterfaceIndex $InterfaceIndex).InterfaceDescription
    $getInterface = Get-NetAdapter -CimSession $CimSession -InterfaceIndex $InterfaceIndex
    $getInterfaceDescription = $getInterface.InterfaceDescription
    $getInterfaceDescription = $getInterfaceDescription.Replace("#","_")
    
    $Redes = Get-CimInstance -ClassName Win32_PerfFormattedData_Tcpip_NetworkAdapter -CimSession $CimSession | Where-Object {$_.Name -eq "$getInterfaceDescription"} | Select-Object Name, CurrentBandwidth, BytesTotalPersec, BytesReceivedPersec, BytesSentPersec, PacketsOutboundErrors
    
    $tempRedePerf = New-Object -Type PSObject
    $CurrentBandwidth = $Redes.CurrentBandwidth / 1000000000
    $CurrentBandwidth = $CurrentBandwidth
    
    $tempRedePerf = [PSCustomObject] @{
        Name = $getInterface.Name
        CurrentBandwidth = $CurrentBandwidth
        BytesTotalPersec = $Redes.BytesTotalPersec
        BytesReceivedPersec = $Redes.BytesReceivedPersec
        BytesSentPersec = $Redes.BytesSentPersec
        PacketsOutboundErrors = $Redes.PacketsOutboundErrors
    }
    
    $redeInfo += $tempRedePerf
}

## GUARDANDO RESULTADOS

$result = [PSCustomObject] @{

        CPUDeviceID = $CPULoad.DeviceID;
        CPUName = $CPULoad.Name;
        CPULoadPercentage = $CPULoad.LoadPercentage;

        MemoriaLoadPercentage = [int]$memory;

        DiscoDeviceID = $diskInfo.DeviceID;
        DiscoFreeSpace = $diskInfo.FreeSpace;
        DiscoSize = $diskInfo.Size;
        DiscoPorcentagem = $diskInfo.Porcentagem;

        DiscoPerfSplitIOPerSec = $disksPerformance.SplitIOPerSec;
        DiscoPerfAvgDiskQueueLength = $disksPerformance.AvgDiskQueueLength;
        DiscoPerfCurrentDiskQueueLength = $disksPerformance.CurrentDiskQueueLength;

        RedeName = $redeInfo.Name;
        RedeCurrentBandwidth = $redeInfo.CurrentBandwidth;
        RedeBytesTotalPersec = $redeInfo.BytesTotalPersec;
        RedeBytesReceivedPersec = $redeInfo.BytesReceivedPersec;
        RedeBytesSentPersec = $redeInfo.BytesSentPersec;
        RedePacketsOutboundErrors = $redeInfo.PacketsOutboundErrors;
    
}

Remove-CimSession -CimSession $CimSession


#### TRATANDO RESULTADOS E GERANDO TEMPLATE DO XML PARA O PRTG INTERPRETAR
@"
<prtg>
    <text>Custom Sensor ESSENCIAL (moises@mmgil.com.br)</text>
"@

    ## TRATANDO RESULTADOS EM RELAÇÃO A CARGA DO PROCESSADOR
    if(($result.CPUDeviceID).count -gt 1){
    
        for ($i=0; $i -lt ($result.CPUDeviceID).count; $i++){
            
            $DeviceID = $result.CPUDeviceID[$i]
            $LoadPercentage = $result.CPULoadPercentage[$i]

@"
    <result>
        <channel>01 $DeviceID</channel>
        <value>$LoadPercentage</value>
        <Unit>Custom</Unit>
        <CustomUnit>%</CustomUnit>
        <LimitMaxError>95</LimitMaxError>
        <LimitMaxWarning>85</LimitMaxWarning>
        <LimitWarningMsg>Cuidado! Processamento acima dos 85%</LimitWarningMsg>
        <LimitErrorMsg>Alerta! Processamento acima dos 95%</LimitErrorMsg>
        <LimitMode>1</LimitMode>
    </result>
"@
        }

    } else {

        $DeviceID = $result.CPUDeviceID
        $LoadPercentage = $result.CPULoadPercentage

@"
    <result>
        <channel>01 $DeviceID</channel>
        <value>$LoadPercentage</value>
        <Unit>Custom</Unit>
        <CustomUnit>%</CustomUnit>
        <LimitMaxError>95</LimitMaxError>
        <LimitMaxWarning>85</LimitMaxWarning>
        <LimitWarningMsg>Cuidado! Processamento acima dos 85%</LimitWarningMsg>
        <LimitErrorMsg>Alerta! Processamento acima dos 95%</LimitErrorMsg>
        <LimitMode>1</LimitMode>
    </result>
"@
    }

    ## TRATANDO RESULTADOS EM RELAÇÃO A MEMORIA
    $CargaMemoria = $result.MemoriaLoadPercentage
@"
    <result>
        <channel>02 Memoria</channel>
        <value>$CargaMemoria</value>
        <Unit>Custom</Unit>
        <CustomUnit>%</CustomUnit>
        <LimitMaxError>95</LimitMaxError>
        <LimitMaxWarning>85</LimitMaxWarning>
        <LimitWarningMsg>Cuidado! Processamento acima dos 85%</LimitWarningMsg>
        <LimitErrorMsg>Alerta! Processamento acima dos 95%</LimitErrorMsg>
        <LimitMode>1</LimitMode>
    </result>
"@

    ## TRATANDO RESULTADOS EM RELAÇÃO AO ESPAÇO EM DISCO
    if(($result.DiscoDeviceID).count -gt 1){
    
        for ($i=0; $i -lt ($result.DiscoDeviceID).count; $i++){
            
            $DiscoDeviceID = $result.DiscoDeviceID[$i]
            $DiscoFreeSpace = $result.DiscoFreeSpace[$i]
            $DiscoPorcentagem = $result.DiscoPorcentagem[$i]

@"
    <result>
        <channel>03 $DiscoDeviceID</channel>
        <value>$DiscoPorcentagem</value>
        <Unit>Custom</Unit>
        <CustomUnit>%</CustomUnit>
        <LimitMaxError>95</LimitMaxError>
        <LimitMaxWarning>85</LimitMaxWarning>
        <LimitWarningMsg>Cuidado! Espaco do Disco $DiscoDeviceID acima dos 85% ($DiscoFreeSpace de espaco Livre)</LimitWarningMsg>
        <LimitErrorMsg>Alerta! Espaco do Disco $DiscoDeviceID acima dos 95% ($DiscoFreeSpace de espaco Livre)</LimitErrorMsg>
        <LimitMode>1</LimitMode>
    </result>
"@
        }

    } else {
        
        $DiscoDeviceID = $result.DiscoDeviceID
        $DiscoFreeSpace = $result.DiscoFreeSpace
        $DiscoPorcentagem = $result.DiscoPorcentagem

@"
    <result>
        <channel>03 $DiscoDeviceID</channel>
        <value>$DiscoPorcentagem</value>
        <Unit>Custom</Unit>
        <CustomUnit>%</CustomUnit>
        <LimitMaxError>95</LimitMaxError>
        <LimitMaxWarning>85</LimitMaxWarning>
        <LimitWarningMsg>Cuidado! Espaco do Disco $DiscoDeviceID acima dos 85% ($DiscoFreeSpace de espaco Livre)</LimitWarningMsg>
        <LimitErrorMsg>Alerta! Espaco do Disco $DiscoDeviceID acima dos 95% ($DiscoFreeSpace de espaco Livre)</LimitErrorMsg>
        <LimitMode>1</LimitMode>
    </result>
"@
    }

    ## TRATANDO RESULTADOS EM RELAÇÃO A MEMORIA
    $DiscoPerfSplitIOPerSec = $result.DiscoPerfSplitIOPerSec
    $DiscoPerfAvgDiskQueueLength = $result.DiscoPerfAvgDiskQueueLength
    $DiscoPerfCurrentDiskQueueLength = $result.DiscoPerfCurrentDiskQueueLength

@"
    <result>
        <channel>03 DISCO Split IO Per Sec</channel>
        <value>$DiscoPerfSplitIOPerSec</value>
    </result>
    <result>
        <channel>03 DISCO Avg Disk Queue Length</channel>
        <value>$DiscoPerfAvgDiskQueueLength</value>
    </result>
    <result>
        <channel>03 DISCO Current Disk Queue Length</channel>
        <value>$DiscoPerfCurrentDiskQueueLength</value>
    </result>
"@

    ## TRATANDO RESULTADOS EM RELAÇÃO AO DESEMPENHO DA REDE
    if(($result.RedeName).count -gt 1){
    
        for ($i=0; $i -lt ($result.RedeName).count; $i++){
            
            $RedeName = $result.RedeName[$i]
            $RedeCurrentBandwidth = $result.RedeCurrentBandwidth[$i]
            $RedeBytesTotalPersec = $result.RedeBytesTotalPersec[$i]
            $RedePacketsOutboundErrors = $result.RedePacketsOutboundErrors[$i]

@"
    <result>
        <channel>04 $RedeName</channel>
        <value>$RedeCurrentBandwidth</value>
        <Unit>Custom</Unit>
        <CustomUnit>Gbps</CustomUnit>
    </result>
    <result>
        <channel>04 ($RedeName) REDE Bytes Total Per Sec</channel>
        <value>$RedeBytesTotalPersec</value>
        <Unit>Custom</Unit>
        <CustomUnit>B/s</CustomUnit>
        <LimitMaxError>100000000</LimitMaxError>
        <LimitMode>1</LimitMode>
    </result>
    <result>
        <channel>04 ($RedeName) REDE Packets Outbound Errors</channel>
        <value>$RedePacketsOutboundErrors</value>
        <Unit>Custom</Unit>
        <CustomUnit>B/s</CustomUnit>
        <LimitMaxError>1</LimitMaxError>
        <LimitMode>1</LimitMode>
    </result>
"@
        }

    } else {
    
        $RedeName = $result.RedeName
        $RedeCurrentBandwidth = $result.RedeCurrentBandwidth
        $RedeBytesTotalPersec = $result.RedeBytesTotalPersec
        $RedePacketsOutboundErrors = $result.RedePacketsOutboundErrors

@"
    <result>
        <channel>04 $RedeName</channel>
        <value>$RedeCurrentBandwidth</value>
        <Unit>Custom</Unit>
        <CustomUnit>Gbps</CustomUnit>
    </result>
    <result>
        <channel>04 ($RedeName) REDE Bytes Total Per Sec</channel>
        <value>$RedeBytesTotalPersec</value>
        <Unit>Custom</Unit>
        <CustomUnit>B/s</CustomUnit>
        <LimitMaxError>100000000</LimitMaxError>
        <LimitMode>1</LimitMode>
    </result>
    <result>
        <channel>04 ($RedeName) REDE Packets Outbound Errors</channel>
        <value>$RedePacketsOutboundErrors</value>
        <Unit>Custom</Unit>
        <CustomUnit>B/s</CustomUnit>
        <LimitMaxError>1</LimitMaxError>
        <LimitMode>1</LimitMode>
    </result>
"@
    }

@"
</prtg>
"@