This readme describes steps to access and configure your personal ENMS Developer VM.
ENMS Developer VMs are Azure Virtual Machines, accessed via Azure Virtual Desktop.

Prerequisites:
- A native Entra ID account in the ENMS Directory
- This account is member of the Developers security group in the ENMS Directory
- A personal GitHub account with access to the [energynet repo](https://github.com/ViaEuropa-Sverige-AB/energynet)
- A Visual Studio license (e.g. attached to an ViaEuropa or Brikks account) that can be used in the VM
- A personal AZD Sesion Host (a VM) has been created for you in the AZD Host Pool for the Azure region closest to you
- Your Entra ID account has been assigned to this Session Host

Steps:
1. Install and use `Windows App` to connect to Azure Virtual Desktop: [doc](https://learn.microsoft.com/en-us/windows-app/get-started-connect-devices-desktops-apps?tabs=windows-avd%2Cwindows-w365%2Cwindows-devbox%2Cmacos-rds%2Cmacos-pc&pivots=azure-virtual-desktop#connect-to-your-devices-and-apps)
2. Login to `Windows App` with the prerequisite Entra Id account. You should see a `Workspace` with an desktop application for your VM, similar to this:<br />
  <img width="599" height="602" alt="image" src="https://github.com/user-attachments/assets/e633c349-7207-4590-be24-ef2383ca52a9" /><br />
  Note that the workspace name ends on an Azure region id, e.g. `-sc` is Sweden Central, `-we` is Western Europe. This should be the Azure region closest to you.
3. Click `Connect` on the desktop image. You should be logged in to the VM with your Entra Id account, which is a local admin on the VM.
4. In the VM, open the browser, login to https://github.com using your personal GitHub account, and download https://github.com/ViaEuropa-Sverige-AB/energynet/blob/main/enms/infra/dev-windows-vm.zip 
5. Unblock the zip file (via file properties), unzip the contents, and copy the full path of the unzipped `install-enms-dev.ps1` (via right-click on the file)
6. Right-click Start Menu -> Windows Terminal (Admin) to open an elevated terminal
7. In the terminal, type `& `, paste the full path to `install-enms-dev.ps1` and press enter, e.g. :<br />
   `& "C:\Users\VincentDev\Downloads\dev-windows-vm\dev-windows-vm\install-enms-dev.ps1"`<br />
   This will install all required software.
   To complete some install steps it may be necessary that you restart the VM or the terminal session - the script will ask you when to do that.
8. Open Visual Studio and sign in with your personal GitHub account when prompted.
9. In Visual Studio, add the account that your VS License is attached to (usually a ViaEuropa or Brikks Entra Id account)
  
Now you are ready to clone the [energynet repo](https://github.com/ViaEuropa-Sverige-AB/energynet) and start developing ENMS!

_dev-windows-vm version: 2025-12-19_
