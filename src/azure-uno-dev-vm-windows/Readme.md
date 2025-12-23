This readme describes steps to access and configure your personal developer VM.
Developer VMs are Azure Virtual Machines, accessed via Azure Virtual Desktop.

Prerequisites:
- A native Entra ID account in the solution directory
- This account is member of the Developers security group in the solution directory
- A GitHub account
- A personal AZD Sesion Host (a VM) has been created for you in the AZD Host Pool for the Azure region closest to you
- Your Entra ID account has been assigned to this Session Host

Steps:
1. Install and use `Windows App` to connect to Azure Virtual Desktop: [doc](https://learn.microsoft.com/en-us/windows-app/get-started-connect-devices-desktops-apps?tabs=windows-avd%2Cwindows-w365%2Cwindows-devbox%2Cmacos-rds%2Cmacos-pc&pivots=azure-virtual-desktop#connect-to-your-devices-and-apps)
2. Login to `Windows App` with the prerequisite Entra Id account. You should see a `Workspace` with a desktop application for your VM.
   Note that the workspace name ends on an Azure region id, e.g. `-sc` is Sweden Central, `-we` is Western Europe. This should be the Azure region closest to you.
3. Click `Connect` on the desktop image. You should be logged in to the VM with your Entra Id account, which is a local admin on the VM.
4. In the VM, open the browser, login to https://github.com using your GitHub account, and download https://github.com/VincentH-Net/azure-uno-dev-vm/tree/main/src/azure-uno-dev-vm-windows.zip 
5. Unblock the zip file (via file properties), unzip the contents, and copy the full path of the unzipped `install.ps1` (via right-click on the file)
6. Right-click Start Menu -> `Windows Terminal (Admin)` to open an elevated terminal
7. In the terminal, type `& `, paste the full path to `install.ps1` and press enter, e.g. :<br />
   `& "C:\Users\VincentDev\Downloads\dev-windows-vm\dev-windows-vm\install.ps1"`<br />
   This will install all required software.
   To complete some install steps it may be necessary that you restart the VM or the terminal session - the script will ask you when to do that.
8. Open Visual Studio and sign in with your GitHub account when prompted.
  
Now you are ready to start developing - NJoy!

_dev-windows-vm version: 2025-12-23_
