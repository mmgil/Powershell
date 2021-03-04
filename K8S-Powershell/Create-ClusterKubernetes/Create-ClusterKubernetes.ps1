<#
.SYNOPSIS
    .Cria maquinas virtuais de acordo com o arquivo JSON de inventario
.EXAMPLE
    
.NOTES
    Author: Moises de Matos Gil
    Date:  Fevereiro, 2021

    NOTAS:
        -> CentOS 7.9

    2021
#>

[CmdletBinding()]
param(
    # PARAMETROS
    [Parameter( Mandatory = $True, ValueFromPipeline = $True, position = 0, HelpMessage = "Informe o arquivo JSON que contemple o inventario dos ambiente que voce deseja montar" )]
    [string]$InventoryFile
)

Begin {
    Write-Host "$(Get-Date) - [INFO]: INICIANDO ACOES" -ForegroundColor Cyan

    Write-Host "$(Get-Date) --> [INFO]: Coletando Invetario" -ForegroundColor DarkBlue
    $inventario = Get-Content $InventoryFile | ConvertFrom-Json

    Write-Host "$(Get-Date) --> [INFO]: Declarando as Funcoes" -ForegroundColor DarkBlue
    function isHypervServer {
        
        Write-Host "$(Get-Date) --> [INFO]: Validando se o HOST e um Hyper-V" -ForegroundColor DarkBlue
        
        if ( (Get-WindowsOptionalFeature -FeatureName Microsoft-Hyper-V -Online).State -eq "Enabled" ) {
            Write-Host "$(Get-Date) ---> [INFO]: Hyper-V Detectado OK" -ForegroundColor DarkGreen
        }
        else {
            Write-Host "$(Get-Date) ---> [WARNING]: Hyper-V NAO Detectado" -ForegroundColor Yellow
            Write-Host "$(Get-Date) ---> [WARNING]: Instale o Hyper-V ou execute esse comando de dentro de um Hyper-V Server" -ForegroundColor Yellow
            break
        }
    }

    function isVMNameExists {
        
        Write-Host "$(Get-Date) --> [INFO]: Validando Nome da VM" -ForegroundColor DarkBlue
        
        $VMs = Get-VM

        $inventario.'virtual-machines'.nodes.node.VMName | ForEach-Object {
            if ( [string]::IsNullOrEmpty( ($VMs | Where-Object Name -eq $_).Name ) ) {
                Write-Host "$(Get-Date) ---> [INFO]: VMName $_ Disponivel para uso" -ForegroundColor DarkGreen
            }
            else {
                Write-Host "$(Get-Date) ---> [WARNING]: Já existe uma VM com o nome $_" -ForegroundColor Yellow
                Write-Host "$(Get-Date) ---> [WARNING]: Altere o seu arquivo de inventario, coloque VMNames que nao estejam em uso no ambiente" -ForegroundColor Yellow
                break
            }
        }
    }

    function isIPAddressExists {
        
        Write-Host "$(Get-Date) --> [INFO]: Validando Enderecamento IP" -ForegroundColor DarkBlue
        
        $IPAddress = Get-VM | Get-VMNetworkAdapter
        $PingObjeto = New-Object System.Net.NetworkInformation.Ping

        $inventario.'virtual-machines'.nodes.node.Network.NetConfigurations.IPAddress | ForEach-Object {
            if ( [string]::IsNullOrEmpty( ($IPAddress | Where-Object IPAddresses -eq $_).IPAddresses ) ) {
                $PingResposta = $PingObjeto.SendPingAsync($_)
                if ( $PingResposta.Result.Status -ne "Success" ) {
                    Write-Host "$(Get-Date) ---> [INFO]: Endereco IP $_ Disponivel para uso" -ForegroundColor DarkGreen
                }
                else {
                    Write-Host "$(Get-Date) ---> [WARNING]: Este Endereco IP $_ já está sendo usado" -ForegroundColor Yellow
                    Write-Host "$(Get-Date) ---> [WARNING]: Altere o seu arquivo de inventario, coloque um Endereco IP que nao esteja em uso no ambiente" -ForegroundColor Yellow
                    break
                }
            }
            else {
                Write-Host "$(Get-Date) ---> [WARNING]: Este Endereco IP $_ já está sendo usado" -ForegroundColor Yellow
                Write-Host "$(Get-Date) ---> [WARNING]: Altere o seu arquivo de inventario, coloque um Endereco IP que nao esteja em uso no ambiente" -ForegroundColor Yellow
                break
            }
        }
    }

    function isMemoryAvailable {

        Write-Host "$(Get-Date) --> [INFO]: Validando Memoria" -ForegroundColor DarkBlue

        $SomaMemoria = 0
        $inventario.'virtual-machines'.nodes.node.MemoryAssigned | ForEach-Object {
            $SomaMemoria = $SomaMemoria + $_
        }

        $SomaMemoria = $SomaMemoria / 1KB ## CONVERTENDO DE BYTE PARA KBYTES

        $TotalMemoryFree = (Get-CIMInstance Win32_OperatingSystem).FreePhysicalMemory ## EM KBYTES

        if ( $TotalMemoryFree -gt $SomaMemoria ) {
            Write-Host "$(Get-Date) ---> [INFO]: Memoria Disponivel para subir o inventario" -ForegroundColor DarkGreen
        }
        else {
            Write-Host "$(Get-Date) ---> [WARNING]: Quantidade de Memoria indisponivel" -ForegroundColor Yellow
            Write-Host "$(Get-Date) ---> [WARNING]: Altere o seu arquivo de inventario para uma quantidde de maquinas que caiba no seu Host ou reveja a quantidade de Memoria RAM no seu Host" -ForegroundColor Yellow
            break
        }
    }

    function isDiskSpaceAvailable {
        
        Write-Host "$(Get-Date) --> [INFO]: Validando Espaco em Disco" -ForegroundColor DarkBlue
        
        ## COLETANDO E UNIFICANDO OS DRIVE LETTER DO INVENTÁRIO
        $unidadesDisco = @()
        ($inventario.'virtual-machines'.nodes.node.Path) | ForEach-Object {
            $unidadesDisco += $_[0]
        }
        $unidadesDisco = $unidadesDisco | Select-Object -Unique

        ## VERIFICANDO O ESPAÇO LIVRE EM CADA DRIVE LETTER E COLOCANDO EM UM HASTABLE
        $TableDisk = @()
        $unidadesDisco | ForEach-Object {
            $TableDisk += [PSCustomObject] @{
                DriveLetter   = $_;
                SizeRemaining = (Get-Volume -DriveLetter $_).SizeRemaining;
            }
        }

        ## EM CADA DRIVE LETTER, VAMOS SOMAR O ESPAÇO QUE O VHD OCUPA E VERIFICAR SE TEM O ESPAÇO LIVRE PRA GUARDAR TODOS OS VHDs
        $TableDisk | ForEach-Object {
            $DriveLetterTemp = $_.DriveLetter
            $SizeRemaining = $_.SizeRemaining
            $SomaDiskSpace = 0
            $inventario.'virtual-machines'.nodes.node | ForEach-Object {
                #Write-Host "node"$_.VMName -ForegroundColor Green
                if ($_.Path[0][0] -eq $DriveLetterTemp) {
                    
                    $VHDxBaseSMB = $_.OperationalSystem.VHDxBaseSMB
                    $VHDxBaseHTTP = $_.OperationalSystem.VHDxBaseHTTP
                    
                    switch ($_.OperationalSystem.VHDxBaseType) {
                        "SMB" {
                            $SomaDiskSpace += (Get-VHD $VHDxBaseSMB).FileSize
                        }
                        "HTTP" { 
                            $webclient = [System.Net.WebRequest]::Create( $VHDxBaseHTTP )
                            $resp = $webclient.GetResponse()
                            $SomaDiskSpace += $resp.ContentLength
                        }
                        Default {
                            Write-Host "$(Get-Date) ---> [WARNING]: Algo deu errado no Calculo do Espaco em Disco" -ForegroundColor Yellow
                            Write-Host "$(Get-Date) ---> [WARNING]: Reveja se o seu arquivo inventario.json realmente está de acordo com o padrão solicitado. Também pode ser algum problema de logica no script, por gentileza abrir um issue" -ForegroundColor Yellow
                            break
                        }
                    }

                    if ( $SizeRemaining -gt $SomaDiskSpace ) {
                        Write-Host "$(Get-Date) ---> [INFO]: Espaco em Disco - OK" -ForegroundColor DarkGreen
                    }
                    else {
                        Write-Host "$(Get-Date) ---> [WARNING]: Ops! a VM"$_.VMName" estoura o Espaco em Disco" -ForegroundColor Yellow
                        Write-Host "$(Get-Date) ---> [WARNING]: Procure alocar essa VM em outra area de disco com espaco disponivel ou remover ela do inventario" -ForegroundColor Yellow
                        break                        
                    }

                }
            }
        }

    }

    Write-Host "$(Get-Date) --> [INFO]: Validando Requisitos" -ForegroundColor DarkBlue
    isHypervServer
    isVMNameExists
    isIPAddressExists
    isMemoryAvailable
    isDiskSpaceAvailable

}

Process {
    Write-Host "$(Get-Date) - [INFO]: PROCESSANDO ACOES" -ForegroundColor Cyan
    
    $QuantidadeServidores = ($inventario.'virtual-machines'.nodes).count
    Write-Host "$(Get-Date) --> [INFO]: Provisionado $QuantidadeServidores Servidores" -ForegroundColor DarkBlue

    $inventario.'virtual-machines'.nodes.node | ForEach-Object {
        if ( -not(Test-Path $_.Path) ) {
            $VirtualHardDiskPath = $_.Path + "/Virtual Hard Disk"
            mkdir $_.Path | Out-Null
            mkdir $VirtualHardDiskPath | Out-Null
        }

        $VMName = $_.VMName

        Write-Host "$(Get-Date) ---> [INFO]: Criando Maquina Virtual"$VMName -ForegroundColor Green
        New-VM -Name "$VMName" -MemoryStartupBytes $_.MemoryAssigned -NoVHD -SwitchName $_.Network.SwitchName -Path $_.Path -Generation 2

        Write-Host "$(Get-Date) ---> [INFO]: Configurando Processador e Memoria" -ForegroundColor Green
        Set-VMProcessor -VMName "$VMName" -Count $_.vCPU
        Set-VMMemory -VMName "$VMName" -DynamicMemoryEnabled $false
        
        Write-Host "$(Get-Date) ---> [INFO]: Provisionando Disco" -ForegroundColor Green
        $VHDxBaseSMB = $_.OperationalSystem.VHDxBaseSMB
        $VHDxBaseHTTP = $_.OperationalSystem.VHDxBaseHTTP
        switch ($_.OperationalSystem.VHDxBaseType) {
            "SMB" {
                $VHDxPath = $VirtualHardDiskPath + "/" + ($VHDxBaseSMB -split "\\")[-1]
                Copy-Item $VHDxBaseSMB -Destination $VHDxPath -Force | Out-Null
            }
            "HTTP" {
                Write-Host "$(Get-Date) ---> [INFO]: Atenção: Trafego via HTTP tende a demorar muito mais, recomendamos baixar o VHDx para algum lugar e referenciar esse lugar no arquivo de inventario" -ForegroundColor DarkCyan
                $VHDxPath = $VirtualHardDiskPath + "/" + ($VHDxBaseHTTP -split "/")[-1]
                Invoke-WebRequest -UseBasicParsing -Uri $VHDxBaseHTTP -OutFile $VHDxPath
            }
            Default {
                Write-Host "$(Get-Date) ---> [WARNING]: Algo deu errado na copia do Disco" -ForegroundColor Yellow
                Write-Host "$(Get-Date) ---> [WARNING]: Reveja se o seu arquivo inventario.json realmente está de acordo com o padrão solicitado. Também pode ser algum problema de logica no script, por gentileza abrir um issue" -ForegroundColor Yellow
                break
            }
        }

        Write-Host "$(Get-Date) ---> [INFO]: Adicionando Disco na VM" -ForegroundColor Green
        Add-VMHardDiskDrive -VMName "$VMName" -ControllerType SCSI -Path $VHDxPath

        Write-Host "$(Get-Date) ---> [INFO]: Configurando Boot da VM" -ForegroundColor Green
        Set-VMFirmware "$VMName" -EnableSecureBoot Off -FirstBootDevice (Get-VMHardDiskDrive -VMName "$VMName" -ControllerLocation 0)

        Write-Host "$(Get-Date) ---> [INFO]: Configurando Integration Service" -ForegroundColor Green
        Enable-VMIntegrationService -VMName "$VMName" -Name "Guest Service Interface"
        
        Write-Host "$(Get-Date) ---> [INFO]: Configurando a Interface de Rede" -ForegroundColor Green
        $OperationMode = $_.Network.VMNetworkAdapterVlan.OperationMode
        $AccessVlanId = $_.Network.VMNetworkAdapterVlan.AccessVlanId
        switch ($OperationMode) {
            "Access" {
                Set-VMNetworkAdapterVlan -VMNetworkAdapter (Get-VMNetworkAdapter "$VMName") -Access -VlanId $AccessVlanId
            }
            "Untagged" {
                Set-VMNetworkAdapterVlan -VMNetworkAdapter (Get-VMNetworkAdapter "$VMName") -Untagged
            }
            Default {
                Write-Host "$(Get-Date) ---> [WARNING]: Algo deu errado na Configuracao da interface de Rede" -ForegroundColor Yellow
                Write-Host "$(Get-Date) ---> [WARNING]: Reveja se o seu arquivo inventario.json realmente está de acordo com o padrão solicitado. Também pode ser algum problema de logica no script, garanta que o OperationMode seja ou Access ou Untagged" -ForegroundColor Yellow
                break
            }
        }

        Write-Host "$(Get-Date) ---> [INFO]: Adicionando Endereço IP na Interface" -ForegroundColor Green
        .\Set-VMNetworkConfiguration.ps1 -NetworkAdapter (Get-VMNetworkAdapter "$VMName") -IPAddress $_.Network.NetConfigurations.IPAddress -Subnet $_.Network.NetConfigurations.MASK -DefaultGateway $_.Network.NetConfigurations.Gateway -DNSServer $_.Network.NetConfigurations.DNSs

        Write-Host "$(Get-Date) ---> [INFO]: Ligando VM" -ForegroundColor Green
        Start-VM "$VMName"
        Start-Sleep -Seconds 20
        Restart-VM "$VMName" -Force

        $PingObjeto = New-Object System.Net.NetworkInformation.Ping
        while ( ($PingObjeto.SendPingAsync( $_.Network.NetConfigurations.IPAddress )).Result.Status -ne "Success" ) {
            Write-Host "$(Get-Date) ---> [INFO]: Aguardando Resposta da VM $VMName" -ForegroundColor Yellow
            Start-Sleep -Seconds 10
        }
    }

    Write-Host "$(Get-Date) --> [INFO]: Configurando SSH-ID nos servidores" -ForegroundColor DarkBlue
    if ( -not(Test-Path ~/.ssh/id_rsa.pub) ) {
        # $passphrase = (New-Guid).Guid
        # $passphrase | Set-Content ~/.ssh/passphrase
        # ssh-keygen.exe -t rsa -b 4096 -C "kubernetes@localhost.domain" -N $passphrase -q -f "$env:USERPROFILE/.ssh/id_rsa"
        ssh-keygen.exe -t rsa -b 4096 -C "kubernetes@localhost.domain" -q -f "$env:USERPROFILE/.ssh/id_rsa" -N """"
    }

    if ( Test-Path ~/.ssh/known_hosts ) {
        Remove-Item ~/.ssh/known_hosts
    }

    if ( (Get-Service ssh-agent).StartType -eq "Disabled" ) {
        Get-Service -Name ssh-agent | Set-Service -StartupType Manual
    }

    $inventario.'virtual-machines'.nodes.node | ForEach-Object {
        $EnderecoIP = $_.Network.NetConfigurations.IPAddress

        Copy-Item "$env:USERPROFILE/.ssh/id_rsa.pub" "$env:USERPROFILE/.ssh/authorized_keys" -Force
        Copy-VMFile -SourcePath "$env:USERPROFILE/.ssh/authorized_keys" -VMName $_.VMName -DestinationPath /root/.ssh/ -Force -FileSource Host -CreateFullPath

        Write-Host "$(Get-Date) ---> [INFO]: Ajustando Usuario e Senha" -ForegroundColor Green
        $rootPassword = $_.rootPassword
        ssh -o "StrictHostKeyChecking no" root@$EnderecoIP "echo root:$rootPassword | chpasswd"

        Write-Host "$(Get-Date) ---> [INFO]: Ajustando Hostname" -ForegroundColor Green
        $hostname = $_.VMName
        ssh -o "StrictHostKeyChecking no" root@$EnderecoIP "hostnamectl set-hostname $hostname"

        Write-Host "$(Get-Date) ---> [INFO]: Ajustando Particao de Boot para UPDATE no CENTOS" -ForegroundColor Green
        $yumConf = ssh -o "StrictHostKeyChecking no" root@$EnderecoIP "cat /etc/yum.conf"
        $yumConf[ $yumConf.IndexOf("installonly_limit=5") ] = "installonly_limit=2"
        $yumConf | Set-Content yum.conf
        Copy-VMFile -SourcePath "./yum.conf" -VMName $_.VMName -DestinationPath /etc/ -Force -FileSource Host -CreateFullPath

        ssh -o "StrictHostKeyChecking no" root@$EnderecoIP "yum install yum-utils -y"
        ssh -o "StrictHostKeyChecking no" root@$EnderecoIP "package-cleanup --oldkernels --count=2 -y"
        ssh -o "StrictHostKeyChecking no" root@$EnderecoIP "yum update --skip-broken -y"
    }

    Write-Host "$(Get-Date) --> [INFO]: Configurando o Controller para o provisionamento do cluster K8S" -ForegroundColor Green

    Write-Host "$(Get-Date) ---> [INFO]: Gerando Inventario do KubeSpray" -ForegroundColor Green
    $all = @()
    $inventario.'virtual-machines'.nodes.node | Where-Object Role -ne "controller" | ForEach-Object {
        $VMName = $_.VMName
        $IPAddress = $_.Network.NetConfigurations.IPAddress
        $all += "$VMName ansible_host=$IPAddress ip=$IPAddress`r`n"
    }

    $masters = @()
    $inventario.'virtual-machines'.nodes.node | Where-Object Role -eq "master" | ForEach-Object {
        $VMName = $_.VMName
        $masters += "$VMName`r`n"
    }

    $kubeNode = @()
    $inventario.'virtual-machines'.nodes.node | Where-Object Role -ne "controller" | ForEach-Object {
        $VMName = $_.VMName
        $kubeNode += "$VMName`r`n"
    }

    $inventoryKubespray = @"
# ## Configure 'ip' variable to bind kubernetes services on a
# ## different ip than the default iface
# ## We should set etcd_member_name for etcd cluster. The node that is not a etcd member do not need to set the value, or can set the empty string value.
[all:vars]
ansible_user = root

[all]
$($all)

# ## configure a bastion host if your nodes are not directly reachable
# [bastion]
# bastion ansible_host=x.x.x.x ansible_user=some_user

[kube-master]
$masters

[etcd]
$masters

[kube-node]
$kubeNode

[calico-rr]

[k8s-cluster:children]
kube-master
kube-node
calico-rr
"@

    $inventoryKubespray | Set-Content inventory.ini
    (Get-Content inventory.ini) -replace "^\s","" | Set-Content inventory.ini

    $inventario.'virtual-machines'.nodes.node | Where-Object Role -eq "controller" | ForEach-Object {
        $EnderecoIP = $_.Network.NetConfigurations.IPAddress
        
        Write-Host "$(Get-Date) ---> [INFO]: Configurando SSH ID" -ForegroundColor Green
        ssh -o "StrictHostKeyChecking no" root@$EnderecoIP "rm ~/.ssh -Rf"
        # ssh -o "StrictHostKeyChecking no" root@$EnderecoIP "ssh-keygen -t rsa -b 4096 -C "kubernetes@localhost.domain" -q -f ~/.ssh/id_rsa -N `"`""

        Copy-VMFile -SourcePath "$env:USERPROFILE/.ssh/id_rsa" -VMName $_.VMName -DestinationPath /root/.ssh/ -Force -FileSource Host -CreateFullPath
        Copy-VMFile -SourcePath "$env:USERPROFILE/.ssh/id_rsa.pub" -VMName $_.VMName -DestinationPath /root/.ssh/ -Force -FileSource Host -CreateFullPath
        Copy-VMFile -SourcePath "$env:USERPROFILE/.ssh/known_hosts" -VMName $_.VMName -DestinationPath /root/.ssh/ -Force -FileSource Host -CreateFullPath
        Copy-VMFile -SourcePath "$env:USERPROFILE/.ssh/authorized_keys" -VMName $_.VMName -DestinationPath /root/.ssh/ -Force -FileSource Host -CreateFullPath
        ssh -o "StrictHostKeyChecking no" root@$EnderecoIP "chmod 600 .ssh/ -R"

        Write-Host "$(Get-Date) ---> [INFO]: Instalando Pre-Requisitos do KubeSpray" -ForegroundColor Green
        ssh -o "StrictHostKeyChecking no" root@$EnderecoIP "yum update -y"
        ssh -o "StrictHostKeyChecking no" root@$EnderecoIP "yum install python3 -y"
        ssh -o "StrictHostKeyChecking no" root@$EnderecoIP "yum install python3-pip -y"
        ssh -o "StrictHostKeyChecking no" root@$EnderecoIP "yum install git -y"
        ssh -o "StrictHostKeyChecking no" root@$EnderecoIP "pip3 install --upgrade setuptools"
        ssh -o "StrictHostKeyChecking no" root@$EnderecoIP "pip3 install --upgrade pip"

        Write-Host "$(Get-Date) ---> [INFO]: Clonando o Repositorio do KubeSpray" -ForegroundColor Green
        ssh -o "StrictHostKeyChecking no" root@$EnderecoIP "git clone https://github.com/kubernetes-sigs/kubespray.git"
        
        Write-Host "$(Get-Date) ---> [INFO]: Instalando o requirements do KubeSpray" -ForegroundColor Green
        ssh -o "StrictHostKeyChecking no" root@$EnderecoIP "cd ./kubespray; pip3 install -r requirements.txt"
        
        Write-Host "$(Get-Date) ---> [INFO]: Ajustando Inventario do KubeSpray" -ForegroundColor Green
        ssh -o "StrictHostKeyChecking no" root@$EnderecoIP "cd ./kubespray; cp -rfp inventory/sample inventory/k8scluster"
        Copy-VMFile -SourcePath "inventory.ini" -VMName kubecontroller -DestinationPath /root/kubespray/inventory/k8scluster/ -Force -FileSource Host -CreateFullPath
        # $inventoryKubespray = ssh -o "StrictHostKeyChecking no" root@$EnderecoIP "cat ./kubespray/inventory/k8scluster/inventory.ini"

        Write-Host "$(Get-Date) ---> [INFO]: Executando playbooks do Ansible no KubeSpray" -ForegroundColor Green
        ssh -o "StrictHostKeyChecking no" root@$EnderecoIP "ansible-playbook -i ./kubespray/inventory/k8scluster/inventory.ini ./kubespray/cluster.yml"
    }
}

End {
    Write-Host "$(Get-Date) - [INFO]: FINALIZANDO ACOES" -ForegroundColor Cyan

    Write-Host "$(Get-Date) --> [INFO]: UFA! Ficou um Scriptao mas espero que voce tenha conseguido subir o seu K8S no Hyper-V" -ForegroundColor DarkBlue

}