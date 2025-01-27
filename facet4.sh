#!/bin/bash


# Facet4 macOS Configuration Script
# Author: Hermann Heringer
# Version : 0.4
# Source: https://github.com/hermannheringer/


# 1º - Disable SIP: Boot into Recovery Mode 'Command (⌘) + R'(Intel-based Macs).
#      - Press and hold the **Power** button until "Loading startup options" appears (M-based Macs).
#      - Select "Utilities" and then "Terminal" from the menu and run 'csrutil disable'.
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
        nvram boot-args="serverperfmode=1 ${current_args#boot-args=}"
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
defaults write NSGlobalDomain NSAppSleepDisabled -bool true

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
# launchctl kickstart -k system/com.apple.SystemUIServer
killall SystemUIServer

echo "Application Nap setting updated. Please verify changes if needed."



# Disable Spotlight indexing and related metadata services to reduce disk I/O
# macOS uses various background services like Spotlight and Time Machine that can increase disk activity.
# This script stops and disables Spotlight's metadata indexing.
echo "Disabling Spotlight indexing and metadata services..."

# Attempt to disable Spotlight indexing across all volumes
if mdutil -a -i off; then
    echo "Spotlight indexing disabled on all volumes."
else
    echo "Failed to disable Spotlight indexing on some volumes. Please check permissions or the state of the volumes."
fi

# Attempt to clear existing Spotlight index to free up disk space
# This is optional but can reduce disk usage if indexing is not needed
if mdutil -a -E; then
    echo "Existing Spotlight index cleared."
else
    echo "Failed to clear existing Spotlight index. Please check permissions."
fi

# Disable the Spotlight menu bar icon
defaults write com.apple.Spotlight menuBarIconVisible -bool false

# Disable the Spotlight indexing and metadata services
defaults write com.apple.Spotlight disabled -bool true

launchctl bootout "com.apple.metadata.mds"
launchctl disable "com.apple.metadata.mds"
launchctl remove system/"com.apple.metadata.mds"

# You can check the status of the indexing and metadata services using the following commands:
log show --predicate 'subsystem == "com.apple.metadata.mds"' | grep -i spotlight



# Reduce Motion & Transparency on macOS
# Disables window animations and reduces transparency for improved performance and lower resource usage.
echo "Disabling animations and reducing transparency..."

# Step 1: Disable window animations globally
defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false

# Step 2: Enable accessibility settings to reduce motion and transparency
defaults write com.apple.Accessibility DifferentiateWithoutColor -bool true
defaults write com.apple.Accessibility ReduceMotionEnabled -bool true
defaults write com.apple.universalaccess reduceMotion -bool true
defaults write com.apple.universalaccess reduceTransparency -bool true

# Step 3: Apply settings for current user's host
defaults -currentHost write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false
defaults -currentHost write com.apple.universalaccess reduceMotion -bool true
defaults -currentHost write com.apple.universalaccess reduceTransparency -bool true

# Step 4: Restart services to ensure settings take effect
# Note: You might need for these if the services are not owned by the current user
killall Dock
killall SystemUIServer




echo "Disabling Feedback Assistant..."
# Disable Feedback Assistant visibility
defaults write com.apple.feedbackassistant showFeedbackAssistant -bool false

# Restart services that might be affected by these changes
# This step is optional and meant for immediate effect; a system restart would also work
killall Finder
killall SystemUIServer

echo "Feedback Assistant processing completed."



# Disable Dashboard (Deprecated in macOS Catalina and later)
echo "Disabling Dashboard..."

# Step 1: Disable Dashboard using defaults (only effective on macOS Mojave and earlier)
defaults write com.apple.dashboard mcx-disabled -bool true

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
        if launchctl bootout system "$service"; then
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
defaults write com.apple.mail DisableInlineAttachmentViewing -bool true

# Step 3: Disable Spotlight indexing for Mail
# Adds Mail to the Spotlight exclusion list
if mdutil -i off /System/Applications/Mail.app; then
    echo "Spotlight indexing for Mail is disabled."
else
    echo "Failed to disable Spotlight indexing for Mail. Please check permissions."
fi

# Clear existing Spotlight index for Mail (optional)
if mdutil -E /System/Applications/Mail.app; then
    echo "Existing Spotlight index for Mail cleared."
else
    echo "Failed to clear Spotlight index for Mail."
fi

# Step 4: Verification to ensure settings are applied
sleep 1
current_setting=$(defaults read com.apple.mail DisableInlineAttachmentViewing 2>/dev/null)
if [ "$current_setting" == "1" ]; then
    echo "Mail inline attachment viewing successfully disabled."
else
    echo "Failed to disable inline attachment viewing in Mail."
fi

# Check if Spotlight indexing for Mail is off
mail_indexing_status=$(mdutil -s /System/Applications/Mail.app | grep "Indexing disabled")
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
    if tmutil disable; then
        echo "Time Machine automatic backups successfully disabled."
    else
        echo "Failed to disable Time Machine automatic backups."
    fi

    # Step 3: Check for running Time Machine processes
    if pgrep -x "backupd" > /dev/null; then
        echo "Time Machine backup daemon is currently running. Attempting to stop..."

        # Force stop the daemon
        if killall backupd; then
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



echo "Disabling Siri & Voice Services..."

# Disable Siri
defaults write com.apple.Siri Enable -bool false

# Disable Siri visibility in the menu bar
defaults write com.apple.Siri StatusMenuVisible -bool false

# Set that the user has declined to enable Siri
defaults write com.apple.Siri UserHasDeclinedEnable -bool true

# Disable the Speech Recognition system
defaults write com.apple.speech.recognition "SpeechRecognitionEnabled" -bool false

# Disable the Dictation system
defaults write NSGlobalDomain DictationIM -bool false
defaults write com.apple.assistant.dictation DictationIM -bool false

# Disable VoiceOver
defaults write com.apple.universalaccess com.apple.AccessibilityVoiceOverEnabled -bool false

# Disable the Speech Synthesis voice
defaults write com.apple.universalaccess "com.apple.speech.synthesis.voiceover" -bool false

# Restart services that might be affected by these changes

killall Finder
killall SystemUIServer

echo "Siri and Voice Services processing complete."




echo "Disabling Finder Tags..."
# Desativar a exibição de tags recentes no Finder
defaults write com.apple.finder ShowRecentTags -bool false

# Desativar a barra lateral de tags no Finder
defaults write com.apple.finder ShowTagsInSidebar -bool false

# Desativar a exibição de tags no menu de contexto (quando você clica com o botão direito em um arquivo)
defaults write com.apple.finder ShowTagsInContextualMenu -bool false

# Desativar a sincronização de tags entre dispositivos (se você estiver usando iCloud Drive)
defaults write NSGlobalDomain NSDocumentAsynchronousKeyValueStore -bool false

# Reiniciar o Finder para aplicar as mudanças
killall Finder

echo "Finder Tags have been disabled."



# Disable Recent Apps in Dock
# Showing recent apps in the Dock can consume memory and CPU resources.
echo "Disabling Recent Apps in Dock..."

# Step 1: Disable the "Recent Apps" feature in the Dock
defaults write com.apple.dock show-recents -bool false

# Step 2: Restart the Dock to apply changes immediately
killall Dock

echo "Recent Apps in Dock have been disabled."



# Disable Desktop Stacks
# The Stacks feature organizes files on the desktop but can increase memory usage.
echo "Disabling Desktop Stacks..."

# Step 1: Disable the "Use Stacks" feature on the Desktop
defaults write com.apple.finder UseStacks -bool false

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
defaults write -g NSQuitAlwaysKeepsWindows -bool false

# Optional (if applicable): Reduce frequency of system updates check, which can also decrease plist activity
defaults write com.apple.SoftwareUpdate ScheduleFrequency -int 30

# Step 2: Attempt a cache reduction to decrease the footprint of cfprefsd
defaults write com.apple.cfprefsd ReduceDaemonActivity -bool true

echo "cfprefsd adjustments complete."




# The CrashReporter reports application crashes and sends information to Apple. Disabling it can save disk space and reduce resource usage.
echo "Disabling CrashReporter..."

# Disable CrashReporter dialog pop-up
defaults write com.apple.CrashReporter DialogType none

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

pmset -a sms 0
pmset -a hibernatemode 0
pmset -a autopoweroff 0

echo "Sudden Motion Sensor (SMS) has been disabled."



# Adjust TCP KeepAlive
# Modifying TCP KeepAlive behavior can optimize network performance on systems that handle numerous connections.
echo "Adjusting TCP KeepAlive..."

# Step 1: Set TCP KeepAlive temporarily
sysctl -w net.inet.tcp.always_keepalive=0

# Step 2: Make the change persistent by adding it to /etc/sysctl.conf
if ! grep -q "net.inet.tcp.always_keepalive=0" /etc/sysctl.conf 2>/dev/null; then
    echo "net.inet.tcp.always_keepalive=0" | tee -a /etc/sysctl.conf > /dev/null
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
sysctl -w net.inet.tcp.recvspace=65536
sysctl -w net.inet.tcp.sendspace=65536

# Step 2: Make the change persistent by adding it to /etc/sysctl.conf
if ! grep -q "net.inet.tcp.recvspace=65536" /etc/sysctl.conf 2>/dev/null; then
    echo "net.inet.tcp.recvspace=65536" | tee -a /etc/sysctl.conf > /dev/null
fi
if ! grep -q "net.inet.tcp.sendspace=65536" /etc/sysctl.conf 2>/dev/null; then
    echo "net.inet.tcp.sendspace=65536" | tee -a /etc/sysctl.conf > /dev/null
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

dscacheutil -flushcache
echo "dscacheutil cache flushed."



# Disable File Quarantine for Downloaded Files
# File Quarantine is a macOS feature that flags downloaded files as potentially unsafe,
# requiring confirmation to open. Disabling it may improve performance for frequent downloads.
echo "Disabling File Quarantine for Downloaded Files..."

# Disable the quarantine flag by modifying LaunchServices
defaults write com.apple.LaunchServices LSQuarantine -bool false
defaults write com.apple.LaunchServices LSQuarantine -bool false

# Disable the quarantine alert by modifying LaunchServices
defaults write com.apple.LaunchServices LSQuarantineAlert -bool false

# Remove any existing quarantine flags for downloaded files
find /var/db/SystemPolicy -name '*.db' -delete

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
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user

# Verification step (optional): Check if the reset improved performance in file associations
sleep 1

echo "LaunchServices Database reset successfully."






echo "Disabling Analytics and Data Collection Service..."

# Disable system analytics and diagnostic reports if not already disabled
defaults write com.apple.CrashReporter DialogType none
defaults write com.apple.CrashReporter UseCrashReporter -bool false
defaults write com.apple.usage_stats AllowSubmission -bool false

# Disable analytics for individual users if not already disabled
if [[ $(defaults read com.apple.SubmitDiagInfo AutoSubmit 2>/dev/null) != "0" ]]; then
    defaults write com.apple.SubmitDiagInfo AutoSubmit -bool false
fi
    
if [[ $(defaults read com.apple.SubmitDiagInfo ThirdPartyDataSubmit 2>/dev/null) != "0" ]]; then
    defaults write com.apple.SubmitDiagInfo ThirdPartyDataSubmit -bool false
fi


# Analytics and Diagnostics
    # com.apple.analyticsd
    # com.apple.crashreporterd
    # com.apple.CrashReporterSupportHelper
    # com.apple.diagnosticd
    # com.apple.dtrace
    # com.apple.emond.aslmanager
    # com.apple.logd
    # com.apple.logd_helper
    # com.apple.aslmanager
    # com.apple.memoryanalyticsd
    # com.apple.spindump_agent
    # com.apple.ReportGPURestart
    # com.apple.ReportCrash
    # com.apple.ReportCrash.Root
    # com.apple.ReportCrash.SafetyNet
    # com.apple.ReportMemoryException
    # com.apple.ReportPanic
    # com.apple.ReportSystemCrash
    # com.apple.spindump
    # com.apple.SubmitDiagInfo
    # com.apple.syslogd
    # com.apple.systemstats.analysis
    # com.apple.systemstats.daily
    # com.apple.systemstats.microstackshot_periodic
    # com.apple.usagestats
    # com.apple.watchdogd

# Siri and Speech
    # com.apple.Siri
    # com.apple.Siri.agent
    # com.apple.parsec-fbf
    # com.apple.siriknowledged
    # com.apple.speech.speechsynthesisd
    # com.apple.speech.synthesisserver
    # com.apple.speech.recognitionserver
    # com.apple.speech.feedbackservicesserver
    # com.apple.speech.voiceinstallerd
    # com.apple.speech.speechdatainstallerd
    # com.apple.DictationIM
    # com.apple.assistantd
    # com.apple.assistant_service
    # com.apple.SiriAnalytics
    # com.apple.voiceservicesd

# Accessibility
    # com.apple.universalaccessd
    # com.apple.voicememod
    # com.apple.accessibility.dfrhud
    # com.apple.accessibility.heard
    # com.apple.accessibility.AXVisualSupportAgent
    # com.apple.accessibility.mediaaccessibilityd
    # com.apple.VoiceOver

# Feedback and Usage
    # com.apple.appleseed.seedusaged
    # com.apple.appleseed.seedusaged.postinstall
    # com.apple.appleseed.fbahelperd
    # com.apple.feedback.relay
    # com.apple.feedback.reporter
    # com.apple.AOSPushRelay

# Network and Sharing
    # com.apple.parentalcontrols.check
    # com.apple.familycontrols.useragent
    # com.apple.screensharing.MessagesAgent
    # com.apple.screensharing.agent
    # com.apple.screensharing.menuextra

# Media and Analytics
    # com.apple.gamed
    # com.apple.rtcreportingd
    # com.apple.photoanalysisd
    # com.apple.mediaanalysisd
    # com.apple.wifianalyticsd

# Advertising and Privacy
    # com.apple.ap.adprivacyd
    # com.apple.ap.adservicesd

# System Services
    # com.apple.ActivityMonitor

# Miscellaneous
    # com.apple.touristd
    # com.apple.KeyboardAccessAgent
    # com.apple.SocialPushAgent
    # com.apple.helpd
    # com.apple.macos.studentd


# Unload analytics and diagnostic services if they are currently loaded
declare -a services=(
    "com.apple.analyticsd"
    "com.apple.crashreporterd"
    "com.apple.CrashReporterSupportHelper"
    "com.apple.diagnosticd"
    "com.apple.dtrace"
    "com.apple.emond.aslmanager"
    "com.apple.logd"
    "com.apple.logd_helper"
    "com.apple.aslmanager"
    "com.apple.memoryanalyticsd"
    "com.apple.spindump_agent"
    "com.apple.ReportGPURestart"
    "com.apple.ReportCrash"
    "com.apple.ReportCrash.Root"
    "com.apple.ReportCrash.SafetyNet"
    "com.apple.ReportMemoryException"
    "com.apple.ReportPanic"
    "com.apple.ReportSystemCrash"
    "com.apple.spindump"
    "com.apple.SubmitDiagInfo"
    "com.apple.syslogd"
    "com.apple.systemstats.analysis"
    "com.apple.systemstats.daily"
    "com.apple.systemstats.microstackshot_periodic"
    "com.apple.usagestats"
    "com.apple.watchdogd"
    "com.apple.Siri"
    "com.apple.Siri.agent"
    "com.apple.parsec-fbf"
    "com.apple.siriknowledged"
    "com.apple.speech.speechsynthesisd"
    "com.apple.speech.synthesisserver"
    "com.apple.speech.recognitionserver"
    "com.apple.speech.feedbackservicesserver"
    "com.apple.speech.voiceinstallerd"
    "com.apple.speech.speechdatainstallerd"
    "com.apple.DictationIM"
    "com.apple.assistantd"
    "com.apple.assistant_service"
    "com.apple.SiriAnalytics"
    "com.apple.voiceservicesd"
    "com.apple.universalaccessd"
    "com.apple.voicememod"
    "com.apple.accessibility.dfrhud"
    "com.apple.accessibility.heard"
    "com.apple.accessibility.AXVisualSupportAgent"
    "com.apple.accessibility.mediaaccessibilityd"
    "com.apple.VoiceOver"
    "com.apple.appleseed.seedusaged"
    "com.apple.appleseed.seedusaged.postinstall"
    "com.apple.appleseed.fbahelperd"
    "com.apple.feedback.relay"
    "com.apple.feedback.reporter"
    "com.apple.AOSPushRelay"
    "com.apple.parentalcontrols.check"
    "com.apple.familycontrols.useragent"
    "com.apple.screensharing.MessagesAgent"
    "com.apple.screensharing.agent"
    "com.apple.screensharing.menuextra"
    "com.apple.gamed"
    "com.apple.rtcreportingd"
    "com.apple.photoanalysisd"
    "com.apple.mediaanalysisd"
    "com.apple.wifianalyticsd"
    "com.apple.ap.adprivacyd"
    "com.apple.ap.adservicesd"
    "com.apple.ActivityMonitor"
    "com.apple.touristd"
    "com.apple.KeyboardAccessAgent"
    "com.apple.SocialPushAgent"
    "com.apple.helpd"
    "com.apple.macos.studentd"
)

for service in "${services[@]}"; do
    # Primeiro, verificamos se o serviço está carregado como um serviço do sistema
    if launchctl list | grep -q "system/$service"; then
        launchctl bootout system/"$service" 2>/dev/null && echo "Booted out system/$service" || echo "Failed to boot out system/$service"
        
        launchctl disable system/"$service" 2>/dev/null && echo "Disabled system/$service permanently" || echo "Could not disable system/$service permanently"
        
        launchctl remove system/"$service" 2>/dev/null && echo "Removed system/$service" || echo "Failed to remove system/$service"
    else
        # Se não for um serviço do sistema, assumimos que é de usuário
        if launchctl list | grep -q "$service"; then
            launchctl bootout "$service" 2>/dev/null && echo "Booted out user/$service" || echo "Failed to boot out user/$service"
            
            launchctl disable "$service" 2>/dev/null && echo "Disabled user/$service permanently" || echo "Could not disable user/$service permanently"
            
            launchctl remove "$service" 2>/dev/null && echo "Removed user/$service" || echo "Failed to remove user/$service"
        else
            echo "$service is not currently loaded, skipping operations."
        fi
    fi
    echo 
    sleep 1
done

# sudo launchctl print system

# Final message
echo "Analytics and Data Collection services have been disabled. A restart may be required for all changes to take full effect."


# sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.sysmond.plist



echo "Blocking telemetry and tracking by adding entries to the hosts file on macOS."

chmod 644 /etc/hosts

# Caminho do arquivo hosts e do backup
hostsPath="/etc/hosts"
backupPath="/etc/hosts.bak"

# Cria um backup do arquivo hosts, se não existir
if [ ! -f "$backupPath" ]; then
    cp "$hostsPath" "$backupPath"
    echo "Backup do arquivo hosts criado em $backupPath."
else
    echo "Backup já existente em $backupPath."
fi

# Lista de domínios para bloquear
telemetryDomains="
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
127.0.0.1    blocklists.settings.services.mozilla.com
127.0.0.1    crash-stats.mozilla.com
127.0.0.1    data.mozilla.com
127.0.0.1    fxmetrics.mozilla.com
127.0.0.1    incoming.telemetry.mozilla.org
127.0.0.1    shavar.services.mozilla.com
127.0.0.1    telemetry.mozilla.org
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
127.0.0.1    oneclient.sfx.ms
"

# Verifica e adiciona domínios apenas se não existirem no arquivo
for domain in $(echo "$telemetryDomains" | awk '{print $2}'); do
    if ! grep -q "$domain" "$hostsPath"; then
        echo "127.0.0.1    $domain" | tee -a "$hostsPath" > /dev/null
    else
        echo "O domínio $domain já está bloqueado no arquivo hosts."
    fi
done

echo "Telemetry and tracking domains have been blocked in the hosts file."
sleep 1

dscacheutil -flushcache
killall -HUP mDNSResponder



# Prompt user to restart the system
response=$(osascript -e 'tell app "System Events" to display dialog "Would you like to restart the system now?" buttons {"Later", "Restart Now"} default button "Restart Now"')

# Check user response
if [[ $response == *"button returned:Restart Now"* ]]; then
    echo "Restarting the system..."
    shutdown -r now
else
    echo "You chose to restart later. Please remember to restart your system to apply changes."
fi
