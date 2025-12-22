# Azure Virtual Desktop Configuration

Developer VM's are Azure Virtual Machines, created by Azure Virtual Desktop (AVD).

## Security

- VM's are personal.
- Each VM is assigned to one specific Entra ID account via AVD Host Pools.
- The Entra ID account is a member of the Developers security group and requires MFA. The Azure role assignments for the Developers group will be set in below steps, after the AVD Host Pool is created.
- VM's do not have public IP addresses, and can only be accessed via Azure Virtual Desktop.
- VM's allow clipboard sharing between the local machine and the VM; all other device sharing options are left at their defaults (which is most secure).
- VM's use Aspire to deploy locally on the machine; deployment to Azure resources is done via CI/CD
- Each AVD Host Pool has a System-assigned managed identity, which has the `Desktop Virtualization Power On Contributor` role
  on the Azure `Subscription` of the Host Pool (subscription level scope is required for the role, to start VM's in that Host Pool).

## Cost Management

VM's are started by AVD when the user connects, and stopped at a daily scheduled time - or before that by the user via the VM blade in the Azure portal

## VM Configuration

- Azure Region: closest to the user
- Latest Windows 11 Enterprise image
- Size: latest generation F16as_v6
  - 16 vCPUs (singe logical core per physical core)
  - 64 GiB RAM
- OS Disk: 512 GiB Premium SSD
- No Infrastructure Redundancy

## AVD Host Pool Configuration

One Host Pool per Azure Region where developers are located. A Host Pool contains all Developer VM's in that region.
**Note** that the Host Pool itself may be in a different region if host pools are not supported in the VM's region.

Steps to create a host pool in the Azure portal:

1. Create a new default `Virtual network` in the `rg-dev-vm` resource group
   1. Region: set to the region closest to the users that will use the VM's - the VM's will be created in this region.
   2. Name: `vnet-dev-avd-` plus a short id indicating the VM Azure region selected in the previous step, e.g. `sc` for Sweden Central, `-we` for Western Europe<br />
      This **VM Azure region id** will be used in later steps.
   3. In the `Tags` tab, add `environment` : `dev`
2. Create a new `Host pool` resource in the `rg-dev-vm` resource group
3. Name: `hp-dev-` plus the **VM Azure region id**
4. Location: set to the same region as the VM Azure region if host pools are supported there; otherwise set to the nearest region that supports host pools
5. Set `Preferred app group type` to `Desktop`
6. Set `Host pool type` to `Personal`.
7. Set `Assignment type` to `Direct`
8. In the `Session hosts` tab:
   1. Set `Add virtual machines` to `Yes`
   2. Set `Name prefix` to `sh-dev-` plus the **VM Azure region id**
   3. If needed set the `Virtual machine location` to the region indicated in the host pool name
      (this is only needed if the VM region does not support host pools, so the host pool was created in another region)
   4. Set `Availability options` to `No infrastructure redundancy required`
   5. Set `Image` to latest `Windows 11 Enterprise`
   6. Set `Virtual machine size` to latest generation `D8as`
   7. Set `Number of virtual machines` to what is needed
   8. Set `OS disk type` to `Premium SSD`
   9. Set `OS disk size` to `512 GiB`
   10. For `Virtual network` select the vnet created in the first step
   11. Select `Microsoft Entra Id` for the directory type
   12. For the `Virtual machine administrator account` select user name `dev` and a securely generated password, stored for `break glass` situations
9. In the `Workspace` tab:
   1. Set `Register desktop app group in a workspace` to `Yes`
   2. Create a new `Workspace` named `ws-dev-` plus the **VM Azure region id**
10. In the `Management` tab, `Assign Managed Identity` and `Create new system-assigned managed identity`
11. In the `Tags` tab, add `environment` : `dev`

Review and create the host pool.

First ensure that the Developers group has the following Azure role assignments:

- `Virtual Machine Administrator Login` on the resource group that contains the host pool: `rg-dev-vm`
- `Desktop Virtualization User` on the Application group that was created for the host pool (the Application group will have the name of the host pool, suffixed with `-DAG` for Desktop Application Group, so `hp-dev-...-DAG`)

Then go to the host pool and:

1. Enable Start VM On Connect:
   1. Under `Identity` select `Azure Role Assignments`created for the host pool to have the `Desktop Virtualization Power On Contributor` role
   on the Azure `Subscription` that contains the host pool (subscription level scope is required for the role)
   2. Under `Properties` enable `Start VM on connect` and `Save` the settings
2. Configure the `RDP Properties`:
   1. Set `Microsoft Entra single sign-on` to be used
   2. Set `Clipboard redirection` to `Clipboard on local computer is available in remote session`
   3. Set `Keyboard redirection` to `(Desktop only) Windows key combinations are applied on the remote computer when in focus`
   4. Set `Multiple displays` to `Don't enable multi-monitor support`
   5. Set `Screen mode` to `The remote session will appear in a window`
   6. Set `Dynamic resolution` to `Session resolution updates as the local window resizes`
   7. Set `Desktop size to 1600 x 1200`
   8. `Save` the RDP Properties
3. In the host pool's application group:
   4. `Assign` the `Developers` security group
   5. Change the `Display name` for the `SessionDesktop` application to `<solution name> Dev Desktop`
4. Assign the Developer Entra ID accounts to their respective session hosts in the host pool
5. For each VM:
   1. Assign it's developer the `Virtual Machine Contributor` role, to allow them to stop the VM when not in use
   2. Enable `Auto-shutdown` at `19:00:00` in the developer's local time zone, with notification sent to their email before shutdown

Inform the developers that their VM is ready. Include:

- the UPN for the account assigned to their VM
- a link to the VM blade in the Azure portal
- a link to (or copy of) the [Developer VM Readme](/src/azure-uno-dev-vm-windows/Readme.md) with steps to access and configure their VM.
- explanation that the VM will be started automatically when they connect via Azure Virtual Desktop, and stopped automatically at 19:00 each day - or they can stop it manually via the Azure portal when not in use.
