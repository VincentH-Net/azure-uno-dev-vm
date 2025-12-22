# azure-uno-dev-vm (WIP - eta before xmas)

Quickly create secure, performant Windows virtual machines for developing Microsoft Azure and Uno Platform solutions with .NET

Developing on a desktop / laptop gives good performance and developer control at low cost, however:
- Security in an enterprise context can be at risk, or strict general purpose security policies interfere with development tasks.
- Stability tends to degrade over time as more software is installed, especially when researching and working on solutions with differing tech stacks.
- Consistency across team members is hard to achieve, leading to "it works on my machine" issues and incomplete local testing.

When developing Azure solutions, a good alternative is to use Windows virtual machines with Azure Virtual Desktop.
- Performance is close to a fast desktop machine when using the right VM size - TODO see proof below
- Developer control is unfettered
  - Each VM is personal
  - The dev has local admin rights on their VMs
  - General purpose desktop/laptop security policies do not interfere
- Costs are limited to actual usage
  - Azure Virtual Desktop automatically starts VMs when users connect
  - VMs are scheduled to be deallocated daily after working hours
  - Devs have control to deallocate their VMs earlier when not needed
- Security is ensured without complexity
  - Users authenticate to AZD and on the VM with Entra ID - use MFA, no local accounts
  - VMs are not directly accessible from the internet - only through Azure Virtual Desktop
  - Aspire can be used to test on the VM, while only CI/CD has access to deploy to Azure.
- Stability and consistency become easy
  - The consistent begin state provided by the known VM image allows to maintain a simple scripted installation of required software and configuration.
  The installation script is idempotent, so it can be re-run as needed to fix issues or to update the VM.
  - Making a new VM in Azure Virtual Desktop is quick and easy, allowing to start fresh when needed, or to create multiple machines per developer to work with products with differing tech stacks.

This repository provides:
- A PowerShell installation script to set up a Windows 11 VM for Azure and Uno Platform development with .NET
- Instructions to create and configure secure Azure Virtual Desktop Windows VMs for development.
- Guidance on selecting performant and cost effective Azure VM sizes for development.

## 1. Configure Azure Virtual Desktop

TODO

## 2. Configure Azure Windows VM

## 3. Scripted development software install and configuration


## VM size Performance

To compare VM performance to a desktop dev machine, I timed builds (initial, incremental and rebuild) of the default Uno Platform solution wizard project (which targets .NET 10 Desktop, WASM, iOS and Android) in Visual Studio 2026.

| Machine | Initial build | Minimal change build | Rebuild |
| --- | --: | --: | --: |
| Desktop | 1m 33s | 9s | 52s |
| D8as_v6 | 2m 23s | 15s | 1m 12s |
| F16as_v6 | 1m 48s | 11s | 57s |
| FX4mds_v2 | 5m | 46s | 2m 36s |

Desktop: AMD Ryzen 9 5950X, 16 cores, boosting ~4.35 GHz, 32 GB RAM, NVMe SSD

When using a latest generation VM size D8as_v6, which has 4 real cores (8 logical) and 32 GB RAM with a premium NVMe SSD, 
the build times prove to be CPU limited, and about 50% - 70% slower than the desktop.

While the D series are general purpose, the F series are compute optimized - a better match for our use case.
The D series simulate 2 logical cores for each physical one, but the F series maintain a 1 on 1 ratio.

When using a F16as_v6 VM size, 16 cores, boosting ~3.7 GHz, Premium NVMe SSD, the perf is close to the desktop.

Wnen using an FX series, which has higher clock CPU but less cores, the VM was 2.5 - 4 times slower than the desktop; clearly not a good fit.

**Conclusion**: use a last generation F series with enough cores to get close to desktop perf.

## Cost

TODO

## azure-uno-dev-vm-windows configuration

The Powershell install script for this Windows 11 machine is idempotent (so you can run it as often as you want), uses mostly WinGet, and ensures below is installed and configured:

- PowerShell 7 or later (default for Windows 11 is still PowerShell 5)

- If needed, resizes the OS drive to use all available space  
  (when you specify a larger size disk in Azure VM, the disk image is not automatically expanded)

- WSL2 (for use by Docker Desktop)

- Docker Desktop

- Azure CLI

- Git for Windows incl Git Credential Manager

- Azure Storage Explorer

- Aspire CLI

- Visual Studio Enterprise 2026 with required workloads and extensions (uses .vsconfig, easy to modify)

- Visual Studio Code with extensions (uses a text file with extensions, easy to modify)

- Uno.Check dotnet tool.  
  The tool is installed and ensures all prerequisites for targets Desktop, WASM, iOS and Android (easy to modify with command-line parameters)

- Trust .NET HTTPS dev certificate

- Accept Android SDK licenses.  
  This works around an issue where VisualStudio Android builds fail and the built-in license accept does not work.

- Oh-My_POSH powershell prompt plus CascadiaMono font to display prompt & terminal icons

- PowerShell TerminalIcons

- PowerShell profile configuration
  - .NET 10 CLI tab completion
  - AZ tab completion
  - Custom Oh-My_POSH theme atomic-min-dotnet-git-az.omp with:  
    - Simplified 2-line prompt based on atomic theme look, with full current path on the first prompt, plus the current Git branch (only when in a repo). The second line has the full console width available for what you type.
    - Tooltip for AZ that shows the current Entra directory name, Azure subscription name and user - only when you are typing an AZ command.
    - tooltip for dotnet that shows the .NET version - only when you type a dotnet command
  - Terminal Icons enabled

## Secure with Entra ID and Azure Virtual Desktop

TODO

## Azure Windows VM configuration

TODO

## Azure Windows VM installation

TODO
