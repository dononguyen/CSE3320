# Running a Provided VM Image on Windows or macOS

## Table of Contents

- [Installation](#installation)
    - [For Windows Users](#for-windows-users)
    - [For macOS Users](#for-macos-users)

## Installation 

### For **Windows** Users:

1. **Download VMware Workstation:**
    - Download from box (UVA login required): https://virginia.box.com/s/drrnvm7o7h6e7lvhh6jaq1ogwqrk3nx1
    - Alternatively, download the latest version from the [VMware Workstation website](https://www.vmware.com/products/workstation-pro.html).   
        - Windows: VMWare workstation Player 17
        - Linux: VMware fusion 13.6.2

2. **Install VMware Workstation:**
   - Run the installer and follow the on-screen instructions, accepting the license agreement.
   - Choose the installation path and complete the installation.
   - Restart the computer if prompted.

3. **Open VMware Workstation:**
   - Launch VMware Workstation from the Start Menu or desktop shortcut.

4. **Download a Ubuntu image and Create a VM:**
   - **Download a Ubuntu Image**:
     - Link for [AMD64](https://releases.ubuntu.com/jammy/)
     - Link for [ARM64/AArch64](https://cdimage.ubuntu.com/ubuntu/releases/22.04/release/)
   - **Create a VM in VMWare Fusion/Workstation**
     - Suggested storage size: 80 GB or more 

5. **Configure VM Settings (if needed):**
   - Right-click the VM in VMware Workstation and select **Settings** to adjust memory, CPU, or network configurations if necessary.

6. **Run the VM:**
   - Click **Power on this virtual machine** to start using the VM.

7. **Shut Down the VM:**
   - Either use **Shut Down Guest** from VMware’s **Power** menu or shut down the operating system inside the VM.

8. (Optional) If you download the Server edition, install the GUI via running the following commands 
````bash
# Update OS and reboot it
sudo apt update && sudo apt upgrade
sudo reboot

# After login, install ubuntu-desktop GUI
sudo apt install ubuntu-desktop
````

---

### For **macOS** Users:

1. **Download VMware Fusion:**
   - Download from box (UVA login required): https://virginia.box.com/s/drrnvm7o7h6e7lvhh6jaq1ogwqrk3nx1
   - Alternatively, go to the [VMware Fusion website](https://www.vmware.com/products/fusion.html).
      - Download the macOS version (VMware Fusion Player is free for personal use, while Pro requires a license).

3. **Install VMware Fusion:**
   - Open the downloaded `.dmg` file and drag the VMware Fusion icon to the Applications folder.
   - Launch VMware Fusion and follow any setup instructions, such as allowing permissions in **System Preferences > Security & Privacy**.

4. **Open VMware Fusion:**
   - Start VMware Fusion from the Applications folder.

5. **Download a Ubuntu image and Create a VM:**
   - **Download a Ubuntu Image**:
     - Link for [AMD64](https://releases.ubuntu.com/jammy/)
     - Link for [ARM64/AArch64](https://cdimage.ubuntu.com/ubuntu/releases/22.04/release/)
   - **Create a VM in VMWare Fusion/Workstation**
     - Suggested storage size: 80 GB or more 

6. **Configure VM Settings (if needed):**
   - Click on **Virtual Machine > Settings** to adjust memory, CPU, or other settings.

7. **Run the VM:**
   - Click **Play** or **Start Up** to power on the VM.
   - To enable copy/paste across the VM and the host, do 
```
sudo apt install open-vm-tools-desktop
```
   - also cf: https://chatgpt.com/share/6795614b-5de8-8004-959c-6b02a22b15f2


8. **Shut Down the VM:**
   - Choose **Shut Down** from VMware Fusion’s **Virtual Machine** menu or shut down the OS inside the VM.

9. (Optional) If you download the Server edition, install the GUI via running the following commands 
````bash
# Update OS and reboot it
sudo apt update && sudo apt upgrade
sudo reboot

# After login, install ubuntu-desktop GUI
sudo apt install ubuntu-desktop
````

## (Optional) Setting up VM for development for rpi3 hardware

see [../rpi3/README.md](../rpi3/rpi3-setup.md)
