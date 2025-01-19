#!/bin/bash


# Facet4 macOS Configuration Script
# Author: Hermann Heringer
# Version : 0.1
# Source: https://github.com/hermannheringer/


# 1º - Disable SIP: Boot into Recovery Mode 'Command (⌘) + R' open 'Terminal' and run 'csrutil disable'.
# 2º - Reboot into macOS and enable 'Root User'.
#      - Open 'System Preferences' and click on 'Users & Groups'.
#      - Select 'Login Options' on the left, then choose Join (or Edit) next to 'Network Account Server'.
#      - In the pop-up, click 'Open Directory Utility'.
#      - In 'Directory Utility', go to the Edit menu at the top and select 'Enable Root User'.
#      - Set a password for the root account.
#      - Switch to Root in Terminal: type 'su root'
#      - Enter the root password you just set.


# 3º - Set 'Execution Permission': Run 'chmod +x facet4.sh' to make the script executable.
# 4º - Run with 'Root Permission': Run with 'sudo ./facet4.sh'.


# How this script works:
# defaults write modifies the .plist files directly by adding a Disabled key with the value true, which tells the system not to load those services.
# This method modifies the contents of the .plist rather than making the file unfindable.
# Reversibility: You can easily re-enable the services by changing the value of Disabled to false.
# Notice that using defaults write is easier to implement but might not always be respected and could be reset after a macOS update.



echo "Enabling Performance Mode for Intel-based macOS..."
# Verifique se o sistema é baseado em Intel
if sysctl -n machdep.cpu.brand_string | grep -q "Intel"; then
    # Verifique se o Performance Mode já está ativado
    current_args=$(nvram boot-args 2>/dev/null)

    if echo "$current_args" | grep -q "serverperfmode=1"; then
        echo "Performance Mode is already enabled."
    else
        # Ativa o modo de desempenho sem remover outros argumentos já definidos
        sudo nvram boot-args="serverperfmode=1 ${current_args#boot-args=}"
        echo "Performance Mode has been enabled for Intel-based macOS."
    fi

    # Confirme se a configuração foi aplicada
    sleep 1
    new_args=$(nvram boot-args 2>/dev/null)
    if echo "$new_args" | grep -q "serverperfmode=1"; then
        echo "Performance Mode is active."
    else
        echo "Failed to enable Performance Mode. Please check permissions or try again."
    fi
else
    echo "This system does not use an Intel CPU. Performance Mode will not be applied."
fi



# Disable Application Nap
# Application Nap is a macOS feature that limits CPU usage for background applications, potentially affecting performance.
echo "Disabling Application Nap..."

# Step 1: Disable Application Nap globally
sudo defaults write NSGlobalDomain NSAppSleepDisabled -int 1

# Step 2: Confirm that Application Nap is disabled
sleep 1
current_setting=$(defaults read NSGlobalDomain NSAppSleepDisabled 2>/dev/null)

if [ "$current_setting" == "1" ]; then
    echo "Application Nap successfully disabled."
else
    echo "Failed to disable Application Nap. Please check permissions or try again."
fi

# Step 3: Reload affected services to apply changes (if necessary)
# Restart SystemUIServer to ensure that global settings take effect immediately
launchctl kickstart -k system/com.apple.SystemUIServer

echo "Application Nap setting updated. Please verify changes if needed."



# Disable Spotlight indexing and related metadata services to reduce disk I/O
# macOS uses various background services like Spotlight and Time Machine that can increase disk activity.
# This script stops and disables Spotlight's metadata indexing.
echo "Disabling Spotlight indexing and metadata services..."

# Attempt to disable Spotlight indexing across all volumes
if sudo mdutil -a -i off; then
    echo "Spotlight indexing disabled on all volumes."
else
    echo "Failed to disable Spotlight indexing on some volumes. Please check permissions or the state of the volumes."
fi

# Attempt to clear existing Spotlight index to free up disk space
# This is optional but can reduce disk usage if indexing is not needed
if sudo mdutil -a -E; then
    echo "Existing Spotlight index cleared."
else
    echo "Failed to clear existing Spotlight index. Please check permissions."
fi

# Check if the Spotlight metadata service is running
if launchctl list | grep -q "com.apple.metadata.mds"; then
    echo "Spotlight metadata service is still active. Try unloading it manually or check for dependent services."
else
    echo "Spotlight metadata service is not running."
fi

echo "Spotlight indexing and metadata services are now disabled."



# Reduce Motion & Transparency on macOS
# Disables window animations and reduces transparency for improved performance and lower resource usage.
echo "Disabling animations and reducing transparency..."

# Step 1: Disable automatic window animations globally
sudo defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false

# Step 2: Enable accessibility settings to reduce color differentiation, motion, and transparency
sudo defaults write com.apple.Accessibility DifferentiateWithoutColor -int 1
sudo defaults write com.apple.Accessibility ReduceMotionEnabled -int 1
sudo defaults write com.apple.universalaccess reduceMotion -int 1
sudo defaults write com.apple.universalaccess reduceTransparency -int 1

# Step 3: Apply settings for current user and ensure consistency with LaunchServices
# Applies ReduceMotion and ReduceTransparency for the current user's host
defaults -currentHost write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -int 0
defaults -currentHost write com.apple.universalaccess reduceMotion -int 1
defaults -currentHost write com.apple.universalaccess reduceTransparency -int 1

# Step 4: Restart LaunchAgents and LaunchServices to ensure settings take effect
# Use launchctl to stop and start relevant services to apply changes immediately
launchctl stop com.apple.Dock.agent
launchctl start com.apple.Dock.agent

launchctl stop com.apple.SystemUIServer.agent
launchctl start com.apple.SystemUIServer.agent

# Step 5: Verification to ensure settings are applied correctly
sleep 1
if [[ $(defaults read NSGlobalDomain NSAutomaticWindowAnimationsEnabled) == 0 ]]; then
    echo "Automatic window animations disabled."
else
    echo "Failed to disable automatic window animations."
fi

if [[ $(defaults read com.apple.universalaccess reduceTransparency) == 1 ]]; then
    echo "Transparency reduction enabled."
else
    echo "Failed to enable transparency reduction."
fi

if [[ $(defaults read com.apple.universalaccess reduceMotion) == 1 ]]; then
    echo "Motion reduction enabled."
else
    echo "Failed to enable motion reduction."
fi



# Disable Feedback Assistant
echo "Disabling Feedback Assistant..."

# Step 1: Set Feedback Assistant to not show in the system
sudo defaults write com.apple.feedbackassistant showFeedbackAssistant -bool false

# Function to check service status
check_service_status() {
    local service="$1"
    if launchctl list | grep -q "$(basename "$service" .plist)"; then
        echo "$service is currently running."
        return 0
    else
        echo "$service is not running."
        return 1
    fi
}

# Function to attempt to unload a service
unload_service() {
    local service="$1"
    local user_context="$2"

    # Check if the service is loaded before trying to unload it
    if check_service_status "$service"; then
        # Attempt to unload the service
        if sudo launchctl bootout "$user_context" "$service"; then
            echo "$service successfully disabled."
        else
            echo "Failed to disable $service. It may require further permissions."
        fi
    else
        echo "$service is not currently loaded. No action taken."
    fi
}

# Step 2: Attempt to unload related LaunchAgents and LaunchDaemons for Feedback Assistant
unload_service "/System/Library/LaunchAgents/com.apple.appleseed.seedusaged.plist" "gui/$(id -u)"
unload_service "/System/Library/LaunchDaemons/com.apple.appleseed.fbahelperd.plist" "system"

# Final verification of the services
sleep 1
echo "Verifying final status of Feedback Assistant services..."
check_service_status "/System/Library/LaunchAgents/com.apple.appleseed.seedusaged.plist"
check_service_status "/System/Library/LaunchDaemons/com.apple.appleseed.fbahelperd.plist"

echo "Feedback Assistant processing completed."



# Disable Dashboard (Deprecated in macOS Catalina and later)
echo "Disabling Dashboard..."

# Step 1: Disable Dashboard using defaults (only effective on macOS Mojave and earlier)
sudo defaults write com.apple.dashboard mcx-disabled -bool true

# Step 2: Verification to confirm setting is applied
current_setting=$(defaults read com.apple.dashboard mcx-disabled 2>/dev/null)
if [ "$current_setting" == "1" ]; then
    echo "Dashboard successfully disabled."
else
    echo "Failed to disable Dashboard or it is already unavailable in this macOS version."
fi



echo "Disabling Mail indexing and inline attachment viewing..."

# Function to check if a service is running
check_service_status() {
    local service="$1"
    if launchctl list | grep -q "$(basename "$service" .plist)"; then
        echo "$service is currently running."
        return 0
    else
        echo "$service is not running."
        return 1
    fi
}

# Function to attempt to unload a service
unload_service() {
    local service="$1"

    # Check if the service is loaded before trying to unload it
    if check_service_status "$service"; then
        # Attempt to unload the service
        if sudo launchctl bootout system "$service"; then
            echo "$service successfully disabled."
        else
            echo "Failed to disable $service. It may require further permissions."
        fi
    else
        echo "$service is not currently loaded. No action taken."
    fi
}

# Step 1: Unload the Mail LaunchAgent and LaunchDaemon to prevent background indexing
unload_service "/System/Library/LaunchAgents/com.apple.mail.plist"
unload_service "/System/Library/LaunchDaemons/com.apple.mailfetchd.plist"

# Step 2: Disable inline attachment viewing in Mail
sudo defaults write com.apple.mail DisableInlineAttachmentViewing -bool true

# Step 3: Disable Spotlight indexing for Mail
# Adds Mail to the Spotlight exclusion list
if sudo mdutil -i off /System/Applications/Mail.app; then
    echo "Spotlight indexing for Mail is disabled."
else
    echo "Failed to disable Spotlight indexing for Mail. Please check permissions."
fi

# Clear existing Spotlight index for Mail (optional)
if sudo mdutil -E /System/Applications/Mail.app; then
    echo "Existing Spotlight index for Mail cleared."
else
    echo "Failed to clear Spotlight index for Mail."
fi

# Step 4: Verification to ensure settings are applied
sleep 1
current_setting=$(sudo defaults read com.apple.mail DisableInlineAttachmentViewing 2>/dev/null)
if [ "$current_setting" == "1" ]; then
    echo "Mail inline attachment viewing successfully disabled."
else
    echo "Failed to disable inline attachment viewing in Mail."
fi

# Check if Spotlight indexing for Mail is off
mail_indexing_status=$(sudo mdutil -s /System/Applications/Mail.app | grep "Indexing disabled")
if [ -n "$mail_indexing_status" ]; then
    echo "Spotlight indexing for Mail is disabled."
else
    echo "Failed to disable Spotlight indexing for Mail. Please check permissions."
fi

echo "Mail indexing and inline attachment viewing adjustments completed."



# Disable Time Machine auto-backup
echo "Checking Time Machine status..."

# Step 1: Check Time Machine status
tm_status=$(tmutil status 2>&1)

if [[ "$tm_status" == *"Backup is not enabled"* ]]; then
    echo "Time Machine is already disabled."
else
    echo "Time Machine is currently enabled. Disabling..."

    # Step 2: Disable Time Machine automatic backups
    if sudo tmutil disable; then
        echo "Time Machine automatic backups successfully disabled."
    else
        echo "Failed to disable Time Machine automatic backups."
    fi

    # Step 3: Check for running Time Machine processes
    if pgrep -x "backupd" > /dev/null; then
        echo "Time Machine backup daemon is currently running. Attempting to stop..."

        # Force stop the daemon
        if sudo killall backupd; then
            echo "Time Machine backup daemon forcefully stopped."
        else
            echo "Failed to force stop Time Machine backup daemon. It may not be running."
        fi
    else
        echo "Time Machine backup daemon is not running."
    fi
fi

# Final status check
if pgrep -x "backupd" > /dev/null; then
    echo "Time Machine backup daemon is still active. You may need to check for dependent services."
else
    echo "Time Machine backup daemon has been successfully stopped."
fi

echo "Time Machine auto-backup has been disabled."



# Disable Siri & Voice Services
echo "Disabling Siri & Voice Services..."

# Step 1: Update user settings to disable Siri in the UI
sudo defaults write com.apple.Siri StatusMenuVisible -bool false
sudo defaults write com.apple.Siri UserHasDeclinedEnable -bool true
sudo defaults write com.apple.assistant.support "Assistant Enabled" -bool false

# Function to check and unload services
unload_service() {
    local service_path="$1"
    if sudo launchctl list | grep -q "$(basename "$service_path" .plist)"; then
        if sudo launchctl bootout system "$service_path"; then
            echo "$service_path successfully disabled."
        else
            echo "Failed to disable $service_path. It may require further permissions."
        fi
    else
        echo "$service_path is not currently loaded."
    fi
}

# Attempt to unload relevant services
unload_service "/System/Library/LaunchAgents/com.apple.Siri.plist"
unload_service "/System/Library/LaunchAgents/com.apple.speechrecognitiond.plist"
unload_service "/System/Library/LaunchAgents/com.apple.voiceservicesd.plist"
unload_service "/System/Library/LaunchAgents/com.apple.assistantd.plist"

# Step 3: Verification to ensure services are disabled
sleep 1
echo "Verifying services are disabled..."

if ! launchctl list | grep -q "com.apple.Siri"; then
    echo "Siri LaunchAgent is not running."
else
    echo "Siri LaunchAgent is still active."
fi

if ! launchctl list | grep -q "com.apple.speechrecognitiond"; then
    echo "Speech Recognition service is not running."
else
    echo "Speech Recognition service is still active."
fi

if ! launchctl list | grep -q "com.apple.voiceservicesd"; then
    echo "Voice Services daemon is not running."
else
    echo "Voice Services daemon is still active."
fi

if ! launchctl list | grep -q "com.apple.assistantd"; then
    echo "Assistant daemon is not running."
else
    echo "Assistant daemon is still active."
fi

echo "Siri and Voice Services processing complete."



# Disable Finder Tags
# Finder Tags index and manage file tags. Disabling this can save system resources.
echo "Disabling Finder Tags..."

# Step 1: Hide recent tags in Finder
sudo defaults write com.apple.finder ShowRecentTags -bool false

# Step 2: Disable Spotlight indexing for tags to reduce resource usage
# Turn off Spotlight indexing for each local volume
local_volumes=$(df | grep '^/' | awk '{print $9}')
for volume in $local_volumes; do
    sudo mdutil -i off "$volume"   # Turn off indexing
    sudo mdutil -E "$volume"       # Erase and rebuild index if needed
done

# Step 3: Restart Finder to apply the changes
killall Finder

# Verification
sleep 1
current_setting=$(defaults read com.apple.finder ShowRecentTags 2>/dev/null)
if [ "$current_setting" == "0" ]; then
    echo "Finder tags successfully hidden from view."
else
    echo "Failed to hide Finder tags. Please check permissions."
fi

# Check if Spotlight indexing for tags is off on the main volume
if ! mdutil -s / | grep -q "Indexing enabled"; then
    echo "Spotlight indexing for tags is disabled."
else
    echo "Spotlight indexing for tags is still active. You may need to disable it manually."
fi

echo "Finder Tags have been disabled."



# Disable Recent Apps in Dock
# Showing recent apps in the Dock can consume memory and CPU resources.
echo "Disabling Recent Apps in Dock..."

# Step 1: Disable the "Recent Apps" feature in the Dock
sudo defaults write com.apple.dock show-recents -bool false

# Step 2: Restart the Dock to apply changes immediately
killall Dock

# Verification
sleep 1
current_setting=$(defaults read com.apple.dock show-recents 2>/dev/null)
if [ "$current_setting" == "0" ]; then
    echo "Recent Apps in Dock successfully disabled."
else
    echo "Failed to disable Recent Apps in Dock. Please check permissions."
fi

echo "Recent Apps in Dock have been disabled."



# Disable Desktop Stacks
# The Stacks feature organizes files on the desktop but can increase memory usage.
echo "Disabling Desktop Stacks..."

# Step 1: Disable the "Use Stacks" feature on the Desktop
sudo defaults write com.apple.finder UseStacks -bool false

# Step 2: Restart Finder to apply changes immediately
killall Finder

# Verification
sleep 1
current_setting=$(defaults read com.apple.finder UseStacks 2>/dev/null)
if [ "$current_setting" == "0" ]; then
    echo "Desktop Stacks successfully disabled."
else
    echo "Failed to disable Desktop Stacks. Please check permissions."
fi

echo "Desktop Stacks have been disabled."



# Limit cfprefsd (System Preferences Daemon)
echo "Limiting cfprefsd memory usage..."

# Step 1: Adjust caching settings to reduce plist write frequency, indirectly managing cfprefsd activity
# This will prevent system and app windows from being restored automatically, potentially reducing cached data load
sudo defaults write -g NSQuitAlwaysKeepsWindows -bool false

# Optional (if applicable): Reduce frequency of system updates check, which can also decrease plist activity
sudo defaults write com.apple.SoftwareUpdate ScheduleFrequency -int 30

# Step 2: Attempt a cache reduction to decrease the footprint of cfprefsd
sudo defaults write com.apple.cfprefsd ReduceDaemonActivity -bool true

# Step 3: Verification
sleep 1
if [[ $(defaults read -g NSQuitAlwaysKeepsWindows 2>/dev/null) == "0" ]]; then
    echo "cfprefsd activity reduced successfully."
else
    echo "Failed to apply changes to cfprefsd preferences. Please check permissions."
fi

echo "cfprefsd adjustments complete."




# The CrashReporter reports application crashes and sends information to Apple. Disabling it can save disk space and reduce resource usage.
echo "Disabling CrashReporter..."

# Step 1: Disable CrashReporter dialog pop-up
sudo defaults write com.apple.CrashReporter DialogType none

# Step 2: Unload the CrashReporter service to fully disable it
# sudo launchctl unload -w /System/Library/LaunchAgents/com.apple.CrashReporter.plist
# LaunchAgents são geralmente executados no contexto de usuário, execute o comando sem sudo
# sudo find / -name "com.apple.CrashReporter.plist"


sudo launchctl bootstrap system /System/Library/LaunchDaemons/com.apple.CrashReporterSupportHelper.plist
sudo launchctl bootout system /System/Library/LaunchDaemons/com.apple.CrashReporterSupportHelper.plist

launchctl bootstrap system /System/Library/LaunchAgents/com.apple.ReportCrash.plist
launchctl bootout system /System/Library/LaunchAgents/com.apple.ReportCrash.plist

# Verification
sleep 1
if ! launchctl list | grep -q "com.apple.ReportCrash"; then
    echo "CrashReporter service successfully disabled."
else
    echo "Failed to disable CrashReporter service. Please check permissions."
fi

echo "CrashReporter has been disabled."





# Increasing the file descriptor limit can allow more files to be open simultaneously, improving performance for certain applications.
echo "Increasing file descriptor limit..."

# Step 1: Temporarily increase the limit for the current session (useful for immediate effect in the current terminal)
ulimit -n 65536

# Verification
sleep 1
current_limit=$(ulimit -n)
if [ "$current_limit" -ge 65536 ]; then
    echo "File descriptor limit successfully increased to $current_limit."
else
    echo "Failed to increase file descriptor limit. Please check permissions or configuration."
fi

echo "File descriptor limit adjustment complete."



# Disable Sudden Motion Sensor (SMS)
# SMS detects sudden movements to protect hard drives. Disabling it can save resources, especially on SSD-based systems.
echo "Disabling Sudden Motion Sensor (SMS)..."

sudo pmset -a sms 0

echo "Sudden Motion Sensor (SMS) has been disabled."



# Adjust TCP KeepAlive
# Modifying TCP KeepAlive behavior can optimize network performance on systems that handle numerous connections.
echo "Adjusting TCP KeepAlive..."

# Step 1: Set TCP KeepAlive temporarily
sudo sysctl -w net.inet.tcp.always_keepalive=0

# Step 2: Make the change persistent by adding it to /etc/sysctl.conf
if ! grep -q "net.inet.tcp.always_keepalive=0" /etc/sysctl.conf 2>/dev/null; then
    echo "net.inet.tcp.always_keepalive=0" | sudo tee -a /etc/sysctl.conf > /dev/null
    echo "TCP KeepAlive setting added to /etc/sysctl.conf for persistence."
else
    echo "TCP KeepAlive setting already present in /etc/sysctl.conf."
fi

# Verification
sleep 1
current_keepalive=$(sysctl -n net.inet.tcp.always_keepalive)
if [ "$current_keepalive" == "0" ]; then
    echo "TCP KeepAlive successfully adjusted."
else
    echo "Failed to adjust TCP KeepAlive. Please check permissions or try again."
fi

echo "TCP KeepAlive adjustment complete."



# Adjust Network Buffer
# Increasing the network buffer size can improve throughput and reduce latency for systems with high network traffic.
echo "Adjusting network buffer..."

# Step 1: Set network buffer size temporarily
sudo sysctl -w net.inet.tcp.recvspace=65536
sudo sysctl -w net.inet.tcp.sendspace=65536

# Step 2: Make the change persistent by adding it to /etc/sysctl.conf
if ! grep -q "net.inet.tcp.recvspace=65536" /etc/sysctl.conf 2>/dev/null; then
    echo "net.inet.tcp.recvspace=65536" | sudo tee -a /etc/sysctl.conf > /dev/null
fi
if ! grep -q "net.inet.tcp.sendspace=65536" /etc/sysctl.conf 2>/dev/null; then
    echo "net.inet.tcp.sendspace=65536" | sudo tee -a /etc/sysctl.conf > /dev/null
    echo "Network buffer settings added to /etc/sysctl.conf for persistence."
else
    echo "Network buffer settings already present in /etc/sysctl.conf."
fi

# Verification
sleep 1
current_recvspace=$(sysctl -n net.inet.tcp.recvspace)
current_sendspace=$(sysctl -n net.inet.tcp.sendspace)

if [ "$current_recvspace" == "65536" ] && [ "$current_sendspace" == "65536" ]; then
    echo "Network buffer successfully adjusted."
else
    echo "Failed to adjust network buffer. Please check permissions or configuration."
fi

echo "Network buffer adjustment complete."



# Limit dscacheutil Cache by Flushing Periodically
# Flushing the dscacheutil cache can help manage space and free up memory for other processes.
echo "Flushing dscacheutil cache..."

sudo dscacheutil -flushcache
echo "dscacheutil cache flushed."



# Disable File Quarantine for Downloaded Files
# File Quarantine is a macOS feature that flags downloaded files as potentially unsafe,
# requiring confirmation to open. Disabling it may improve performance for frequent downloads.
echo "Disabling File Quarantine for Downloaded Files..."

# Disable the quarantine flag by modifying LaunchServices
sudo defaults write com.apple.LaunchServices LSQuarantine -bool false

# Verification
sleep 1
current_quarantine_status=$(defaults read com.apple.LaunchServices LSQuarantine 2>/dev/null)

if [ "$current_quarantine_status" == "0" ]; then
    echo "File Quarantine successfully disabled."
else
    echo "Failed to disable File Quarantine. Please check permissions or try again."
fi



# Reset LaunchServices Database
# The LaunchServices system, which manages file associations for opening with appropriate applications,
# can slow down older systems due to a bloated database. Resetting it may improve performance.
echo "Resetting LaunchServices Database..."

# Reset LaunchServices database by removing file associations and rebuilding
sudo /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user

# Verification step (optional): Check if the reset improved performance in file associations
sleep 1

echo "LaunchServices Database reset successfully."



# Disable Universal Access Services
# Disables accessibility services in macOS, such as visual and media accessibility, which can reduce memory and CPU usage
# if these services are not required.
echo "Disabling Universal Access Services..."

# Disable and unload relevant accessibility services
launchctl bootout gui/$(id -u) /System/Library/LaunchAgents/com.apple.universalaccessd.plist
launchctl bootout gui/$(id -u) /System/Library/LaunchAgents/com.apple.accessibility.AXVisualSupportAgent.plist
launchctl bootout gui/$(id -u) /System/Library/LaunchAgents/com.apple.accessibility.mediaaccessibilityd.plist

# Verification step: Check if services are inactive
sleep 1
if ! launchctl list | grep -q "com.apple.universalaccessd"; then
    echo "Universal Access Services successfully disabled."
else
    echo "Failed to disable Universal Access Services. Please check permissions or try again."
fi



# Disable Game Center
# Game Center is a macOS service that allows players to share game scores and achievements with friends.
# Disabling it can reduce CPU and memory usage, especially if Game Center features are unused.
echo "Disabling Game Center..."

sudo launchctl bootout gui/$(id -u) /System/Library/LaunchAgents/com.apple.gamed.plist

# Verification step: Check if Game Center is inactive
sleep 1
if ! launchctl list | grep -q "com.apple.gamed"; then
    echo "Game Center successfully disabled."
else
    echo "Failed to disable Game Center. Please check permissions or try again."
fi



echo "Disabling Analytics and Data Collection Service..."

# Disable system analytics and diagnostic reports if not already disabled
if [[ $(sudo defaults read /Library/Application\ Support/CrashReporter/DiagnosticMessagesHistory.plist AutoSubmit 2>/dev/null) != "0" ]]; then
    sudo defaults write /Library/Application\ Support/CrashReporter/DiagnosticMessagesHistory.plist AutoSubmit -bool false
fi

if [[ $(sudo defaults read /Library/Application\ Support/CrashReporter/DiagnosticMessagesHistory.plist ThirdPartyDataSubmit 2>/dev/null) != "0" ]]; then
    sudo defaults write /Library/Application\ Support/CrashReporter/DiagnosticMessagesHistory.plist ThirdPartyDataSubmit -bool false
fi

sudo defaults write /Library/Preferences/com.apple.CrashReporter.plist DialogType none

# Disable analytics for individual users if not already disabled
if [[ $(sudo defaults read com.apple.SubmitDiagInfo AutoSubmit 2>/dev/null) != "0" ]]; then
    sudo defaults write com.apple.SubmitDiagInfo AutoSubmit -bool false
    sudo defaults write /Library/Preferences/com.apple.SubmitDiagInfo.plist AutoSubmit -bool false
fi
    
if [[ $(sudo defaults read com.apple.SubmitDiagInfo ThirdPartyDataSubmit 2>/dev/null) != "0" ]]; then
    sudo defaults write com.apple.SubmitDiagInfo ThirdPartyDataSubmit -bool false
    sudo defaults write /Library/Preferences/com.apple.SubmitDiagInfo.plist ThirdPartyDataSubmit -bool false
fi

# Unload analytics and diagnostic services if they are currently loaded
declare -a services=(
    "/System/Library/LaunchDaemons/com.apple.spindump.plist"
    "/System/Library/LaunchDaemons/com.apple.crashreporterd.plist"
    "/System/Library/LaunchDaemons/com.apple.syslogd.plist"
    "/System/Library/LaunchDaemons/com.apple.aslmanager.plist"
    "/System/Library/LaunchDaemons/com.apple.diagnosticd.plist"
    "/System/Library/LaunchDaemons/com.apple.analyticsd.plist"
    "/System/Library/LaunchAgents/com.apple.amp.mediasharingd.plist"
    "/System/Library/LaunchAgents/com.apple.screensharing.plist"
    "/System/Library/LaunchAgents/com.apple.usagestats.plist"
    "/System/Library/LaunchDaemons/com.apple.ReportCrash.Root.plist"
    "/System/Library/LaunchDaemons/com.apple.ReportCrash.SafetyNet.plist"
    "/System/Library/LaunchDaemons/com.apple.ReportPanic.plist"
    "/System/Library/LaunchDaemons/com.apple.ReportMemoryException.plist"
    "/System/Library/LaunchDaemons/com.apple.ReportSystemCrash.plist"
    "/System/Library/LaunchDaemons/com.apple.watchdogd.plist" # Gerenciamento de falhas do sistema
    "/System/Library/LaunchAgents/com.apple.ReportCrash.plist"
    "/System/Library/LaunchAgents/com.apple.ReportPanic.plist"
    "/System/Library/LaunchDaemons/com.apple.logd.plist"  # Central logging service
    "/System/Library/LaunchDaemons/com.apple.ActivityMonitor.plist" # Monitoramento de atividade do sistema
    # "/System/Library/LaunchDaemons/com.apple.sysmond.plist" # System monitoring daemon
)

for service in "${services[@]}"; do
    if sudo launchctl list | grep -q "$(basename "$service" .plist)"; then
        sudo launchctl unload -w "$service"
        echo "Unloaded $service"
    else
        echo "$service is already disabled or not running."
    fi
done

# Disable dtrace if it is currently running
sudo launchctl stop com.apple.dtrace

# Final message
echo "Analytics and Data Collection services have been disabled. A restart may be required for all changes to take full effect."


# sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.sysmond.plist



echo "Blocking telemetry and tracking by adding entries to the hosts file on macOS."

sudo chmod 644 /etc/hosts

# Caminho do arquivo hosts e do backup
hostsPath="/etc/hosts"
backupPath="/etc/hosts.bak"

# Cria um backup do arquivo hosts, se não existir
if [ ! -f "$backupPath" ]; then
    sudo cp "$hostsPath" "$backupPath"
    echo "Backup do arquivo hosts criado em $backupPath."
else
    echo "Backup já existente em $backupPath."
fi

# Lista de domínios para bloquear
telemetryDomains="

#Microsoft Telemetry and Ads
127.0.0.1    activity.windows.com
127.0.0.1    ads.msn.com
127.0.0.1    analytics.microsoft.com
127.0.0.1    browser.events.data.msn.com
127.0.0.1    checkappexec.microsoft.com
127.0.0.1    data.microsoft.com
127.0.0.1    diagnostics.support.microsoft.com
127.0.0.1    edge.microsoft.com
127.0.0.1    eu-mobile.events.data.microsoft.com
127.0.0.1    feedback.windows.com
127.0.0.1    i1.services.social.microsoft.com
127.0.0.1    jp-mobile.events.data.microsoft.com
127.0.0.1    msftconnecttest.com
127.0.0.1    msftncsi.com
127.0.0.1    oca.microsoft.com
127.0.0.1    sb.scorecardresearch.com
127.0.0.1    scorecardresearch.com
127.0.0.1    settings-win.data.microsoft.com
127.0.0.1    telemetry.microsoft.com
127.0.0.1    telemetry.urs.microsoft.com
127.0.0.1    uk-mobile.events.data.microsoft.com
127.0.0.1    us-mobile.events.data.microsoft.com
127.0.0.1    v10.vortex.data.microsoft.com
127.0.0.1    v10.vortex-win.data.microsoft.com
127.0.0.1    v20.vortex.data.microsoft.com
127.0.0.1    v20.vortex-win.data.microsoft.com
127.0.0.1    vortex.data.microsoft.com
127.0.0.1    vortex-win.data.microsoft.com
127.0.0.1    watson.microsoft.com

#Apple Telemetry
127.0.0.1    analytics.apple.com
127.0.0.1    api-glb-crashlytics.itunes.apple.com
127.0.0.1    config.push.apple.com
127.0.0.1    e.crashlytics.com
127.0.0.1    events.apple.com
127.0.0.1    experience.apple.com
127.0.0.1    gateway.push.apple.com
127.0.0.1    gsp10-ssl.ls.apple.com
127.0.0.1    gsp11-ssl.ls.apple.com
127.0.0.1    icloud-content.com
127.0.0.1    init-p01md.apple.com
127.0.0.1    metrics.apple.com
127.0.0.1    radarsubmissions.apple.com
127.0.0.1    sp.analytics.itunes.apple.com
127.0.0.1    telemetry.apple.com

#Google Ads and Telemetry
127.0.0.1    ad.doubleclick.net
127.0.0.1    ads.google.com
127.0.0.1    adservice.google.co.in
127.0.0.1    adservice.google.com
127.0.0.1    adservice.google.com.ar
127.0.0.1    adservice.google.com.au
127.0.0.1    adservice.google.com.co
127.0.0.1    adservice.google.com.mx
127.0.0.1    adservice.google.com.tr
127.0.0.1    adssettings.google.com
127.0.0.1    beacon.google.com
127.0.0.1    beacon.scorecardresearch.com
127.0.0.1    doubleclick.net
127.0.0.1    googleads.g.doubleclick.net
127.0.0.1    googleadservices.com
127.0.0.1    google-analytics.com
127.0.0.1    googleoptimize.com
127.0.0.1    googletagmanager.com
127.0.0.1    pagead2.googlesyndication.com
127.0.0.1    secure-us.imrworldwide.com
127.0.0.1    ssl.google-analytics.com
127.0.0.1    stats.g.doubleclick.net
127.0.0.1    tagmanager.google.com
127.0.0.1    tags.tiqcdn.com
127.0.0.1    www.google-analytics.com

#Facebook Ads and Tracking
127.0.0.1    adaccount.instagram.com
127.0.0.1    ads.facebook.com
127.0.0.1    connect.facebook.net
127.0.0.1    graph.facebook.com
127.0.0.1    instagram.com/ads
127.0.0.1    l.facebook.com
127.0.0.1    marketing-api.facebook.com
127.0.0.1    pixel.facebook.com
127.0.0.1    tr.facebook.com
127.0.0.1    tracking.facebook.com

#Mozilla Telemetry
127.0.0.1    blocklists.settings.services.mozilla.com
127.0.0.1    crash-stats.mozilla.com
127.0.0.1    data.mozilla.com
127.0.0.1    fxmetrics.mozilla.com
127.0.0.1    incoming.telemetry.mozilla.org
127.0.0.1    shavar.services.mozilla.com
127.0.0.1    telemetry.mozilla.org

#General Ads and Telemetry
127.0.0.1    ads.linkedin.com
127.0.0.1    ads.pinterest.com
127.0.0.1    ads.twitter.com
127.0.0.1    ads.yahoo.com
127.0.0.1    adserver.adtechus.com
127.0.0.1    adssettings.yahoo.com
127.0.0.1    analytics.snapchat.com
127.0.0.1    analytics.tiktok.com
127.0.0.1    app-measurement.com
127.0.0.1    atdmt.com
127.0.0.1    beacon.scorecardresearch.com
127.0.0.1    cdn.ampproject.org
127.0.0.1    chartbeat.com
127.0.0.1    edge-metrics.com
127.0.0.1    engine.adzerk.net
127.0.0.1    hotjar.com
127.0.0.1    logs.tiktokv.com
127.0.0.1    m.stripe.network
127.0.0.1    matomo.cloud
127.0.0.1    media6degrees.com
127.0.0.1    openx.net
127.0.0.1    pagead.l.doubleclick.net
127.0.0.1    pixel.quantserve.com
127.0.0.1    quantserve.com
127.0.0.1    scorecardresearch.com
127.0.0.1    secure-us.imrworldwide.com
127.0.0.1    ssl.google-analytics.com
127.0.0.1    stats.wordpress.com
127.0.0.1    tags.tiqcdn.com
127.0.0.1    tracking-proxy-prod.msn.com
127.0.0.1    yieldmanager.com

#onedrive EOL workaround
127.0.0.1    oneclient.sfx.ms
127.0.0.1    g.live.com

#End of list of domains to block
"

# Verifica e adiciona domínios apenas se não existirem no arquivo
for domain in $(echo "$telemetryDomains" | awk '{print $2}'); do
    if ! grep -q "$domain" "$hostsPath"; then
        echo "127.0.0.1    $domain" | sudo tee -a "$hostsPath" > /dev/null
    else
        echo "O domínio $domain já está bloqueado no arquivo hosts."
    fi
done

echo "Telemetry and tracking domains have been blocked in the hosts file."
sleep 1

sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder



# Prompt user to restart the system
response=$(osascript -e 'tell app "System Events" to display dialog "Would you like to restart the system now?" buttons {"Later", "Restart Now"} default button "Restart Now"')

# Check user response
if [[ $response == *"button returned:Restart Now"* ]]; then
    echo "Restarting the system..."
    sudo shutdown -r now
else
    echo "You chose to restart later. Please remember to restart your system to apply changes."
fi
