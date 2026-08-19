## Installing WSL2 with Ubuntu 22.04 on Windows

Last updated: Nov 2024

Follow these steps to install WSL2 and set up Ubuntu 22.04 on your Windows machine.

### 1. Enable WSL and Virtual Machine Platform Features

- Open **PowerShell as Administrator** and run the following commands to enable the necessary features:

    ```powershell
    dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
    dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
    ```

### 2. Restart Your Computer

- Restart your machine to ensure that the changes take effect.

### 3. Set WSL2 as the Default Version

- Open **PowerShell as Administrator** again and run the following command to set WSL2 as the default version:

    ```powershell
    wsl --set-default-version 2
    ```

### 4. Install Ubuntu 22.04 from the Microsoft Store

- Open the **Microsoft Store**.
- Search for **Ubuntu 22.04** and select it.
- Click **Get** or **Install** to download and install it.

### 5. Initial Setup of Ubuntu 22.04

- Once installed, launch Ubuntu 22.04 from the Start menu or by typing `wsl` in PowerShell or Command Prompt.
- You’ll be prompted to create a new UNIX username and password. This will be your user account inside Ubuntu.

### 6. Verify Installation

- To confirm that WSL2 and Ubuntu 22.04 are running correctly, open **PowerShell** or **Command Prompt** and type:

    ```powershell
    wsl --list --verbose
    ```

- You should see Ubuntu 22.04 listed, with `Version 2` under the version column.

---

Your WSL2 environment with Ubuntu 22.04 is now ready! You can start using it by launching Ubuntu from the Start menu or by running `wsl` in PowerShell or Command Prompt.

