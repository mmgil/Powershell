# COMO USAR

1) Abra o Powershell no HOST do seu Hyper-v;
2) Navegue até a pasta que você clonou esse projeto: cd .\Powershell\K8S-Powershell\Create-ClusterKubernetes\
3) Execute o comando:

```powershell
.\Create-ClusterKubernetes.ps1 -InventoryFile inventario-sample-UNTAGGED.json
```

Seu cluster de K8S estará pronto para uso depois de vários minutos.

# K8S
O K8S (Kubernetes) sem dúvidas é a sensação do momento e já provou que chegou no mercado para ficar e diminuir as demandas com os serviços de infraestrutura através da sua poderosa arquitetura escalável.

Todas as principais nuvens oferecem o Kubernetes como serviço, o que gera também um alto poder de flexibilidade para a sua aplicação ser o menos lockin possível já que, caso sua aplicação funcione perfeitamente em um cluster de K8S local, com certeza irá funcionar em qualquer nuvem pública nao importa qual ela seja.

Diante disso e vendo ainda o grande poder de infiltração que o Windows 10 PRO tem nas empresas e nos computadores de trabalho da grande maioria das pessoas, sem contar sobre o Hyper-V Server que continua sendo a melhor alternativa para as empresas que querem economizar com virtualização sem abrir mão de uma ferramenta robusta e com alta disponibilidade, resolvi desenvolver esse script para que você, através de um prompt de PowerShell, possa provisionar um cluster de K8S usando o Hyper-V da sua máquina ou o seu Hyper-V de Produção.

Esse Script provisiona as VMs de acordo com o preenchimento do arquivo JSON de inventário. Nos modelos daqui do repositório será provisionado 3 masters e 2 nodes. Um outro servidor chamado controller baixará o projeto Kubespray para realizar a implantação do cluster após provisionamento das VMs. O Kubespray é um projeto para provisionamento de cluster K8S de produção no seu ambiente On Premisses usando o Ansible.

Veja mais sobre o [Kubespray]

[Kubespray]: https://github.com/kubernetes-sigs/kubespray

# REQUISITOS

## Softwares
- Hyper-V (Hyper-V Server Standalone, Windows Server 2019 ou Windows 10 PRO)
- SSH Client habilitado no seu Windows (Hoje já vem nativo, basta apenas testar no Powershell: ssh -v localhost)
- Powershell na versão mínima 5.1 (Requer também o módulo Powershell do Hyper-V)
- Um VHDx template com o CentOS 7.x instalado (Caso queira usar o meu template Clique aqui: [CentOS76])

[CentOS76]: https://sistemasmmgil-my.sharepoint.com/:u:/g/personal/moises_mmgil_com_br/EWdgDytCBPNFuTE0jWSnAiYBsR-SOtU_dpdVMyF10IMIRw?e=3v1SMt

## Hardware
- Memória RAM: 16 GB (mínimo)
- CPU: 8 vCPUs (mínimo)
- HD: 50 GB (mínimo)

Esses requisitos são para um ambiente inicial de Produção, onde o ideal é provisionar no mínimo três servidores masters e quantos nodes você desejar (nesse caso estamos provisionando dois). Mas, caso você queira subir em um ambiente para desenvolvimento, basta editar o arquivo JSON e deixar 1 master com 2 nodes e ajustar as configurações de memoria ram e vCPU de acordo com o poder de processamento da sua máquina.

# PREPAROS

## Primeiro -> Clonar Repositório
Primeira coisa é realizar o clone desse repositório no seu HOST de Hyper-V:

```powershell
git clone https://github.com/mmgil/Powershell.git
```

## Segundo -> Editar o arquivo de inventário

Na pasta K8S-Powershell\Create-ClusterKubernetes você encontrará um arquivo modelo chamado inventario-sample-UNTAGGED.json, do qual basta editar para que o script crie o ambiente de acordo com o que foi preenchido nesse arquivo. Por Padrão o arquivo vem com 6 servidores para serem criados:

- 1 Controller -> este servidor  ficará responsável por instalar o cluster de K8S após o provisionamento das máquinas virtuais.
- 3 Masters -> Serão os servidores responsáveis pelo cluster de K8S.
- 2 Nodes -> Serão os nodes de K8S que hospedará as aplicações deployadas nesse ambiente.

A seguir você pode ler a descrição de cada chave no arquivo json de inventário


| **NOME**                                 | **DESCRIÇÃO**                                                 |
| ----------------------                   | ------------------------------------------------------------- |
| VMName                                   | Será o nome da máquina virtual e o hostname do servidor       |
| Role                                     | A função desse servidor: controller, master ou node           |
| vCPU                                     | Quantidade de vCPUs que essa VM terá                          |
| MemoryAssigned                           | Quantidade de Memória RAM que essa VM terá                    |
| Path                                     | Caminho que essa VM ficará hospedada (ainda sem suporte a CSV)|
| Generation                               | Geração dessa VM no Hyper-V (use Sempre Geração 2)            |
| DynamicMemoryEnabled                     | Desabilita o uso de Memoria Dinamica nesse servidor           |
| rootPassword                             | Senha que você deseja que o root do servidor tenha            |
| OperationalSystem.OperationalSystem      | Nome do Sistema Operacional                                   |
| OperationalSystem.VHDxBaseType           | Modo de como script puxará o VHD template (SMB ou HTTP)       |
| OperationalSystem.VHDxBaseSMB            | Caminho de onde está hospedado o seu template de VHD (crie um ou baixe do site da CentOS ) |
| VHDxBaseHTTP                             | Essa opção é sempre mais lenta, prefira baixar e apontar pelo VHDxBaseSMB |
| Network.SwitchName                       | Nome do seu Swiych Virtual no seu Hyper-V, voce pode ver com o comando: Get-VMSwitch |
| Network.IsLegacy                         | Se nao deseja realizar boot pela rede, deixei em False            |
| Network.DynamicMacAddressEnabled         | Deixe em true para o Hyper-V gerenciar o MACAddres para você      |
| Network.VMNetworkAdapterVlan.OperationMode | Untagged ou Access: deixei sempre em Untagged caso nao esteja em uma rede corporativa que tenha portas em trunk para o Hyper-V |
| NetConfigurations.IPAddress              | Endereço IP que a Máquina Virtual irá Receber                     |
| NetConfigurations.MASK                   | Máscara de Subrede do seu ambiente, normalmente é 255.255.255.0   |
| NetConfigurations.Gateway                | Endereço IP do Roteador do seu ambiente                           |
| NetConfigurations.DNSs                   | Endereços IPs dos Servidores DNS que voce deseja configurar       |
| NetConfigurations.SuffixDNS              | Deixe em true para o Hyper-V gerenciar o MACAddres para você      |

[CentOS]: https://cloud.centos.org/centos/7/vagrant/x86_64/images/CentOS-7.HyperV.box