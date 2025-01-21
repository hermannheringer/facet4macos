![macos_logo.png](README/macos_logo.png)
# Facet4 macOS Optimization and Debloat Script

**Author**: Hermann Heringer  
**Version**: 0.3  
**Repository**: [GitHub](https://github.com/hermannheringer/)


---

The **Facet4 macOS Optimization and Debloat Script** is a tool designed to enhance macOS performance through systematic adjustments to system services, UI settings, and network configurations. It is ideal for users seeking to reduce memory and CPU usage, streamline background processes, and optimize system responsiveness. 

> **Warning**: This script modifies core system configurations and should only be used by advanced users familiar with macOS internals. **Ensure a complete system backup** before proceeding.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Features](#features)
3. [Usage Instructions](#usage-instructions)
4. [Reverting Changes](#reverting-changes)
5. [Compatibility](#compatibility)
6. [Disclaimer](#disclaimer)

---

## Prerequisites

1. **Disable System Integrity Protection (SIP)**:
   - Boot into Recovery Mode (`Command (⌘) + R`) for Intel-based Macs or press and hold the **Power** button until "Loading Startup Options" appears for M-based Macs.
   - Open **Terminal** and run: `csrutil disable`.
   - Restart into macOS with: `sudo reboot now`.

2. **Enable Root User**:
   - Go to **System Preferences** > **Users & Groups**.
   - In **Login Options**, select **Join** next to **Network Account Server**.
   - In **Directory Utility**, enable **Root User** and set a password.
   - Switch to root in Terminal: `su root`.

3. **Set Execution Permissions**:
   - Run `chmod +x facet4.sh` to make the script executable.

4. **Run the Script as Root**:
   - Execute the script using: `sudo ./facet4.sh`.
   - You can either copy, paste, or execute the instructions of your choice in the Terminal.
---

## Features

### 1. Performance Mode (Intel-Based Macs)
   - **Objective**: Enables macOS performance mode for Intel-based systems, enhancing CPU responsiveness.
   - **Commands**: `nvram boot-args="serverperfmode=1"`
   - **Verification**: Confirms through `nvram boot-args` for active setting.

### 2. Application Nap Deactivation
   - **Objective**: Disables Application Nap to prevent throttling of background applications, ensuring consistent multitasking performance.
   - **Commands**: `sudo defaults write NSGlobalDomain NSAppSleepDisabled -bool true`
   - **Verification**: Confirms value with `defaults read`.

### 3. Spotlight Indexing and Metadata Optimization
   - **Objective**: Disables Spotlight indexing to reduce disk I/O, especially beneficial for systems with intensive disk usage.
   - **Commands**:
     - Disable: `mdutil -a -i off`
     - Clear Index: `mdutil -a -E`

### 4. UI Performance Enhancements (Reduce Motion and Transparency)
   - **Objective**: Reduces visual effects for improved system performance, especially on older hardware.
   - **Commands**: Uses `defaults write` to disable window animations, reduce transparency, and enable accessibility optimizations.
   - **Verification**: Confirms through `defaults read` values for animation and transparency settings.

### 5. Feedback Assistant Deactivation
   - **Objective**: Disables Feedback Assistant to conserve system resources.
   - **Commands**: `defaults write com.apple.feedbackassistant showFeedbackAssistant -bool false`
   - **Service Control**: Unloads associated services via `launchctl`.

### 6. Dashboard Removal (macOS Mojave and Earlier)
   - **Objective**: Removes the Dashboard to free up system memory and reduce CPU usage.
   - **Commands**: `sudo defaults write com.apple.dashboard mcx-disabled -bool true`
   - **Verification**: Checks configuration status with `defaults read`.

### 7. Mail Indexing and Inline Attachments Management
   - **Objective**: Reduces CPU load by disabling Mail indexing and inline attachment previews.
   - **Commands**: Uses `mdutil` to disable indexing and configures attachment settings via `defaults write`.

### 8. Time Machine Auto-Backup Control
   - **Objective**: Stops automatic Time Machine backups to prevent unintended disk activity during active use.
   - **Commands**: `tmutil disable`
   - **Daemon Control**: Halts the `backupd` daemon if it’s active.

### 9. Siri and Voice Service Deactivation
   - **Objective**: Disables Siri and related services to reduce background processing.
   - **Commands**: Configures `defaults write` settings to disable Siri.
   - **Service Control**: Stops Siri-related agents and daemons via `launchctl`.

### 10. Finder Tags and Dock Recent Apps Adjustment
   - **Objective**: Disables Finder tags and recent apps in the Dock to reduce UI memory usage.
   - **Commands**:
     - `defaults write com.apple.finder ShowRecentTags -bool false`
     - `defaults write com.apple.finder ShowTagsInSidebar -bool false`
     - `defaults write com.apple.finder ShowTagsInContextualMenu -bool false`
     - `defaults write NSGlobalDomain NSDocumentAsynchronousKeyValueStore -bool false`
     
   - **Restart**: Restarts Finder and Dock to apply settings.

### 11. Network Optimization
   - **Objective**: Improves network efficiency by modifying TCP KeepAlive and buffer settings.
   - **Commands**:
     - TCP KeepAlive: `sysctl -w net.inet.tcp.always_keepalive=0`
     - Buffer Adjustments: `sysctl -w net.inet.tcp.recvspace=65536`, `sysctl -w net.inet.tcp.sendspace=65536`

### 12. Background Service Minimization
   - **Objective**: Optimize System Performance by Disabling Non-Essential macOS Background Services to conserve system resources.

      **Crash Reporting and Diagnostics:**
      - `com.apple.CrashReporterSupportHelper`
      - `com.apple.crashreporterd`
      - `com.apple.diagnosticd`
      - `com.apple.ReportCrash`
      - `com.apple.ReportCrash.Root`
      - `com.apple.ReportCrash.SafetyNet`
      - `com.apple.ReportMemoryException`
      - `com.apple.ReportPanic`
      - `com.apple.ReportSystemCrash`
      - `com.apple.spindump`

      **System Logs and Analytics:**
      - `com.apple.emond.aslmanager`
      - `com.apple.logd`
      - `com.apple.logd_helper`
      - `com.apple.analyticsd`
      - `com.apple.memoryanalyticsd`
      - `com.apple.syslogd`
      - `com.apple.systemstats.analysis`
      - `com.apple.systemstats.daily`
      - `com.apple.systemstats.microstackshot_periodic`
      - `com.apple.usagestats`
      - `com.apple.wifianalyticsd`

      **Accessibility and Universal Access:**
      - `com.apple.universalaccessd`
      - `com.apple.accessibility.AXVisualSupportAgent`
      - `com.apple.accessibility.mediaaccessibilityd`
      - `com.apple.speech.speechsynthesisd`
      - `com.apple.voiceservicesd`

      **Feedback and User Interaction:**
      - `com.apple.appleseed.seedusaged`
      - `com.apple.appleseed.fbahelperd`
      - `com.apple.feedback.relay`
      - `com.apple.feedback.reporter`
      - `com.apple.Siri`
      - `com.apple.assistantd`
      - `com.apple.SiriAnalytics`

      **Game and User Activity Monitoring:**
      - `com.apple.gamed`
      - `com.apple.ActivityMonitor`

      **System Stability and Monitoring:**
      - `com.apple.aslmanager`
      - `com.apple.dtrace`
      - `com.apple.watchdogd`

   - **Service Control**: Disables these services via `launchctl` and `defaults write`.

### 13. Telemetry and Tracking Block
   - **Objective**: Blocks common telemetry and tracking domains, enhancing user privacy by modifying the `/etc/hosts` file.
   - **Domains Blocked**: Microsoft, Apple, Google Analytics, Facebook, and other tracking providers.
   - **Verification**: Ensures all domains are appended to the hosts file, blocking outgoing data requests.

### 14. Additional System Optimizations
   - **Disable Sudden Motion Sensor** (SSD systems): `pmset -a sms 0`
   - **Increase File Descriptor Limit**: Configures a higher file descriptor limit for improved app performance.
   - **Reset LaunchServices Database**: Rebuilds app association database to reduce load times on older systems.

---
![onedrive_logo.png](README/onedrive_logo.png)
**OneDrive Client for macOS 12.x Monterey EOL Workaround**

Microsoft is forcing users to upgrade their Apple hardware by automatically updating the OneDrive client to an incompatible version.

Here’s a temporary workaround:

1. Remove the incompatible OneDrive.app from the Applications folder.
2. Download and install the latest compatible version of the OneDrive client (v24.086.0428.0003) from https://oneclient.sfx.ms/Mac/Installers/24.086.0428.0003/universal/OneDrive.pkg.
3. Block future updates by adding this line to your /etc/hosts file:

   ```
   127.0.0.1 oneclient.sfx.ms
   ```

This should keep OneDrive working until further notice. To aggressively remove the non-working app, use the Terminal command:

```
killall OneDrive

rm -rf "/Applications/OneDrive.app"

rm -rf ~/Library/Application\ Support/OneDrive
rm -rf ~/Library/Caches/com.microsoft.OneDrive
rm -rf ~/Library/Preferences/com.microsoft.OneDrive.plist

rm -rf ~/Library/Containers/com.microsoft.OneDrive*

sudo rm -rf /Library/Preferences/com.microsoft.OneDrive.plist

sudo rm -rf /var/db/receipts/com.microsoft.OneDrive*
sudo rm -rf /Library/Logs/Microsoft/OneDrive

```


---
## Usage Instructions

1. **Run the Script**:
   - Execute the script as root using: `sudo ./facet4.sh`.

2. **Restart the System**:
   - For optimal results, restart the system after running the script to ensure all changes take effect.

3. **Review Changes**:
    - If you are familiar with what you're doing, you might want to download and run `ONYX`(make sure to select the correct version for your macOS). `ONYX` is a multifunctional utility for macOS that allows you to verify the startup disk and the structure of its system files. It can also help you perform cleaning and maintenance tasks, configure hidden parameters for various Apple applications, and much more.

    - Don't waste your valuable time downloading and testing software, and avoid potential malware. Don't fall into this trap; the only tool I recommend is `ONYX`.

    https://www.titanium-software.fr/en/onyx.html

![onyx.jpg](README/onyx.jpg)



---

## Reverting Changes

Most settings can be reverted by adjusting the values in `defaults write` commands.

> Note: Some configurations may reset during macOS updates, which could necessitate reapplying specific settings.

---

## Compatibility

This script is tailored for macOS versions prior to Ventura (macOS 12), where certain services like Dashboard and various system daemons are accessible. Some commands may not be fully compatible with newer macOS releases, and behavior may vary across system versions.

---

## Disclaimer

This script is provided “as is” without warranty. By using this script, you assume all responsibility for any modifications it makes to your system. For further details on macOS configurations, consult Apple’s [official documentation](https://support.apple.com/).

---

For more detailed technical insights, visit [Apple’s macOS documentation](https://support.apple.com/).

---

Have fun!
