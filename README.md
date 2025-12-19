# azure-uno-dev-vm (WIP - eta before xmas)

Quickly create secure, performant Windows virtual machines for developing Microsoft Azure and Uno Platform solutions with .NET

## Performance

To compare VM performance to a desktop dev machine, I timed builds (initial, incremental and rebuild) of the default Uno Platform solution wizard project (which targets .NET 10 Desktop, WASM, iOS and Android) in Visual Studio 2026.

| Machine | Initial build | Minimal change build | Rebuild |
| --- | --: | --: | --: |
| Desktop | 1m 33s | 9s | 52s |
| D8as_v6 | 2m 23s | 15s | 1m 12s |
| F16as_v6 | 1m 48s | 11s | 57s |
| FX4mds_v2 | 5m | 46s | 2m 36s |

Desktop: AMD Ryzen 9 5950X, 16 cores, boosting ~4.35 GHz, 32 GB Ram, NVMe SSD

When using a latest generation VM size D8as_v6, which has 4 real cores (8 logical) and 32 GB Ram with a premium NVMe SSD, the build times prove to be CPU limited, and about 50% - 70% slower than the desktop.

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
