#!/bin/bash


# Facet4 macOS Configuration Script
# Author: Hermann Heringer
# Version : 0.7
# Date: 2025-03-02
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


# sudo find / -name "com.apple.CrashReporter.plist"
# ls /System/Library/LaunchDaemons/ | grep bluetooth
# ls ~/Library/LaunchAgents/ | grep bluetooth
# Verificar se o Domínio Existe
# defaults domains | grep com.apple.screensaver



# Enabling Performance Mode
if sysctl -n machdep.cpu.brand_string | grep -q "Intel"; then
    echo "Enabling Performance Mode for Intel-based macOS..."
    current_args=$(nvram boot-args 2>/dev/null)

    if echo "$current_args" | grep -q "serverperfmode=1"; then
        echo "Performance Mode is already enabled."
    else
        nvram boot-args="serverperfmode=1 debug=0 keepsyms=0 diagsnap=0 nvram_paniclog=0 log=0x0 kextlog=0 oslog=0 kern.hv_vmm_present=1 pmap_cs_disabled=1 ${current_args#boot-args=}"
    fi
    sleep 1
    new_args=$(nvram boot-args 2>/dev/null)
    if echo "$new_args" | grep -q "serverperfmode=1"; then
        echo "Performance Mode is active."
    else
        echo "Failed to enable Performance Mode. Please check permissions or try again."
    fi
else
    echo "Enabling Performance Mode for Apple Silicon-based macOS..."
    current_args=$(nvram boot-args 2>/dev/null)

    if echo "$current_args" | grep -q "serverperfmode=1"; then
        echo "Performance Mode is already enabled."
    else
        nvram boot-args="serverperfmode=1 debug=0 keepsyms=0 diagsnap=0 nvram_paniclog=0 log=0x0 kextlog=0 oslog=0 ${current_args#boot-args=}"
    fi
    sleep 1
    new_args=$(nvram boot-args 2>/dev/null)
    if echo "$new_args" | grep -q "serverperfmode=1"; then
        echo "Performance Mode is active."
    else
        echo "Failed to enable Performance Mode. Please check permissions or try again."
    fi

fi


echo "Disabling Application Nap..."
defaults read NSGlobalDomain
defaults write -g NSAppSleepDisabled -bool true
sudo pmset -a powernap 0 womp 0
sudo pmset -c lowpowermode 0 



echo "Disabling Spotlight indexing and metadata services..."
mdutil -a -i off
mdutil -a -E
mdutil -a -d

defaults read com.apple.suggestions DoNotShowInAllMyFiles
defaults write com.apple.suggestions DoNotShowInAllMyFiles -bool true

defaults read com.apple.suggestions DoNotShowInMenuBar
defaults write com.apple.suggestions DoNotShowInMenuBar -bool true



echo "Disabling Feedback Assistant..."
sudo launchctl print-disabled system | grep appleseed
sudo defaults write /Library/Preferences/com.apple.appleseed.fbahelperd.plist Disabled -bool true

for service in $(sudo launchctl list | grep -i appleseed | awk '{print $3}'); do  
  sudo launchctl disable user/$(id -u)/$service 
  sudo launchctl disable system/$service  
done  



echo "Disables window animations and reduces transparency for improved performance and lower resource usage..."
# Configurações principais de desempenho visual
defaults read -g NSAutomaticWindowAnimationsEnabled
defaults write -g NSAutomaticWindowAnimationsEnabled -bool false

# Redução de movimento e transparência
defaults read com.apple.universalaccess reduceMotion
defaults write com.apple.universalaccess reduceMotion -bool true

defaults read com.apple.universalaccess reduceTransparency
defaults write com.apple.universalaccess reduceTransparency -bool true

defaults read com.apple.Accessibility DifferentiateWithoutColor
defaults write com.apple.Accessibility DifferentiateWithoutColor -bool true

defaults read com.apple.Accessibility ReduceMotionEnabled
defaults write com.apple.Accessibility ReduceMotionEnabled -bool true

# Desabilita o widget de notificação do centro de notificação
defaults write com.apple.notificationcenterui widgetAllowsNMC -bool FALSE

# Desabilita o dashboard
defaults write com.apple.dashboard mcx-disabled -bool TRUE

# Desabilita a animação de expansão do Dock
defaults write com.apple.dock expose-animation-duration -float 0

# Aplica para usuário atual e host
defaults -currentHost write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false
defaults -currentHost write com.apple.universalaccess reduceMotion -bool true
defaults -currentHost write com.apple.universalaccess reduceTransparency -bool true

defaults -currentHost read NSGlobalDomain


# Disable Time Machine auto-backup
echo "Check Time Machine status..."
tmutil status 2>/dev/null
tmutil disable



echo "Disabling Recent Apps in Dock..."
defaults read com.apple.dock show-recents
defaults write com.apple.dock show-recents -bool false



echo "Disabling Finder Tags..."
rm -rf ~/Library/Preferences/com.apple.finder.plist

sudo defaults write com.apple.finder ShowRecentTags -bool false
sudo defaults write com.apple.finder ShowSidebarTagsSection -bool false
sudo defaults write com.apple.finder FXPreferredTagSchemes -array

defaults read com.apple.finder ShowRecentTags


echo "This will prevent system and app windows from being restored automatically, potentially reducing cached data load."
sudo defaults write -g NSQuitAlwaysKeepsWindows -bool false



echo "Reduce frequency of system updates check (5 days), which can also decrease plist activity..."
sudo defaults write com.apple.SoftwareUpdate ScheduleFrequency -int 5



echo "Attempt a cache reduction to decrease the footprint of cfprefsd..."
sudo defaults write com.apple.cfprefsd ReduceDaemonActivity -bool true



echo "Disabling Sudden Motion Sensor (SMS)..."
sudo pmset -a sms 0



# Desativar Relatórios de Falhas (Crash Reporting)
defaults write com.apple.CrashReporter DialogType none

sudo rm -rf /Library/Application\ Support/CrashReporter/DiagnosticMessagesHistory.plist

sudo defaults write /Library/Application\ Support/CrashReporter/DiagnosticMessagesHistory.plist AutoSubmit -bool false
sudo defaults write /Library/Application\ Support/CrashReporter/DiagnosticMessagesHistory.plist ThirdPartyDataSubmit -bool false

# Remove helper privileges
sudo chmod 000 /System/Library/LaunchAgents/com.apple.CrashReporterSupportHelper.plist

defaults read /Library/Application\ Support/CrashReporter/DiagnosticMessagesHistory.plist


# Disable Core component of macOS system analytics.

# Desativar o Daemon logd Manualmente
# O daemon logd é o núcleo do ULS. Mesmo com oslog=0, ele pode ser reativado automaticamente pelo sistema. Para garantir que ele não seja executado:

# Edite o arquivo .plist correspondente:

#sudo nano /System/Library/LaunchDaemons/com.apple.logd.plist
# Adicione a chave <key>Disabled</key> com o valor <true/>:

# <key>Disabled</key>
# <true/>

#Salve o arquivo e reinicie o sistema.

for service in $(sudo launchctl list | grep -i logd | awk '{print $3}'); do  
  sudo launchctl disable user/$(id -u)/$service 
  sudo launchctl disable system/$service  
done

for service in $(sudo launchctl list | grep -i syslogd | awk '{print $3}'); do  
  sudo launchctl disable user/$(id -u)/$service 
  sudo launchctl disable system/$service  
done  

for service in $(sudo launchctl list | grep -i diagnosticd | awk '{print $3}'); do  
  sudo launchctl disable user/$(id -u)/$service 
  sudo launchctl disable system/$service  
done 

for service in $(sudo launchctl list | grep -i aslmanager | awk '{print $3}'); do  
  sudo launchctl disable user/$(id -u)/$service 
  sudo launchctl disable system/$service  
done 

for service in $(sudo launchctl list | grep -i osanalytics | awk '{print $3}'); do  
  sudo launchctl disable user/$(id -u)/$service 
  sudo launchctl disable system/$service  
done  



# Disable symptom framework
sudo defaults write /Library/Preferences/com.apple.symptomsd Analytics -bool false

# Remove symptom database
sudo rm -rf /var/db/symptom_analytics.db*
sudo rm -rf /var/log/DiagnosticMessages/osanalytics*
sudo rm -rf /var/log/DiagnosticMessages/*

# Block network communication
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /usr/libexec/analyticsd --getblockall

# Collects and submits diagnostic/analytics data to Apple.
sudo defaults write /Library/Preferences/com.apple.analyticsd.plist AnalyticsEnabled -bool false


for service in $(sudo launchctl list | grep -i analyticsd | awk '{print $3}'); do  
  sudo launchctl disable user/$(id -u)/$service 
  sudo launchctl disable system/$service  
done  

# Disable Memory pressure analysis
for service in $(sudo launchctl list | grep -i memoryanalyticsd | awk '{print $3}'); do  
  sudo launchctl disable user/$(id -u)/$service 
  sudo launchctl disable system/$service  
done 


# Disable Diagnostic Extensions
for service in $(sudo launchctl list | grep -i diagnosticextensions | awk '{print $3}'); do  
  sudo launchctl disable user/$(id -u)/$service 
  sudo launchctl disable system/$service  
done  

# Check for active analytics processes
ps aux | grep -E 'analyticsd|diagnosticd'





# Siri
defaults read com.apple.assistant.support "Siri Analytics & Privacy"
defaults write com.apple.assistant.support "Siri Analytics & Privacy" -bool false

defaults read com.apple.assistant.support "Assistant Enabled"
defaults write com.apple.assistant.support "Assistant Enabled" -bool false

defaults read com.apple.Siri StatusMenuVisible
sudo defaults write com.apple.Siri StatusMenuVisible -bool false

defaults read com.apple.Siri UserHasDeclinedEnable
sudo defaults write com.apple.Siri UserHasDeclinedEnable -bool true

for service in $(sudo launchctl list | grep -i siri | awk '{print $3}'); do  
  sudo launchctl disable user/$(id -u)/$service 
  sudo launchctl disable system/$service  
done  

for service in $(sudo launchctl list | grep -i assistant_service | awk '{print $3}'); do  
  sudo launchctl disable user/$(id -u)/$service 
  sudo launchctl disable system/$service  
done  

for service in $(sudo launchctl list | grep -i assistantd | awk '{print $3}'); do  
  sudo launchctl disable user/$(id -u)/$service 
  sudo launchctl disable system/$service  
done  

for service in $(sudo launchctl list | grep -i parsec-fbf | awk '{print $3}'); do  
  sudo launchctl disable user/$(id -u)/$service 
  sudo launchctl disable system/$service  
done  

# sudo rm -rf ~/Library/Siri

# VoiceOver & Speech & Accessibility

for service in $(sudo launchctl list | grep -i VoiceOver | awk '{print $3}'); do  
  sudo launchctl disable user/$(id -u)/$service 
  sudo launchctl disable system/$service  
done

for service in $(sudo launchctl list | grep -i voicememod | awk '{print $3}'); do  
  sudo launchctl disable user/$(id -u)/$service 
  sudo launchctl disable system/$service  
done

for service in $(sudo launchctl list | grep -i accessibility | awk '{print $3}'); do  
  sudo launchctl disable user/$(id -u)/$service 
  sudo launchctl disable system/$service  
done

for service in $(sudo launchctl list | grep -i speech | awk '{print $3}'); do  
  sudo launchctl disable user/$(id -u)/$service 
  sudo launchctl disable system/$service  
done









# Limite a coleta de logs relacionados à energia
defaults read /Library/Preferences/com.apple.powermanagement.plist SystemPowerProfile
sudo defaults write /Library/Preferences/com.apple.powermanagement.plist SystemPowerProfile -dict-add "ActivityMonitor" -bool false

# Limpar logs de gerenciamento de energia
sudo rm -rf /var/log/powermanagement/*



#  Desativar Publicidade Personalizada
defaults read com.apple.AdLib allowApplePersonalizedAdvertising
defaults write com.apple.AdLib allowApplePersonalizedAdvertising -bool false


# Disable ARDAgent ( Network/CPU overhead if enabled )
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -deactivate -configure -access -off  
sudo defaults write /Library/Preferences/com.apple.RemoteManagement ARDAgentEnabled -bool false




# Desativa systemstats e bloqueia UsageStats
  sudo launchctl disable user/$(id -u)/com.apple.systemstatsd 
  sudo launchctl disable system/com.apple.systemstatsd    
 
  sudo chmod 000 /var/db/usageStats 

for service in $(sudo launchctl list | grep -i systemstats | awk '{print $3}'); do  
  sudo launchctl disable user/$(id -u)/$service 
  sudo launchctl disable system/$service  
done  

# Remover estatísticas de uso
sudo rm ~/Library/Preferences/com.apple.UsageStats.plist
sudo rm -rf /private/var/db/systemstats/*

# Tracks application usage patterns
sudo defaults write /Library/Preferences/com.apple.UsageAnalytics.plist UsageAnalyticsEnabled -bool false

sudo rm -rf /var/db/UsageAnalyticsLocal/*


# Submits diagnostics to Apple automatically.
defaults read /Library/Preferences/com.apple.SubmitDiagInfo.plist AutoSubmit
sudo defaults write /Library/Preferences/com.apple.SubmitDiagInfo.plist AutoSubmit -bool false

defaults read /Library/Preferences/com.apple.SubmitDiagInfo.plist ThirdPartyDataSubmit
sudo defaults write /Library/Preferences/com.apple.SubmitDiagInfo.plist ThirdPartyDataSubmit -bool false

for service in $(sudo launchctl list | grep -i ReportCrash | awk '{print $3}'); do  
  sudo launchctl disable user/$(id -u)/$service 
  sudo launchctl disable system/$service  
done  

for service in $(sudo launchctl list | grep -i ReportGPURestart | awk '{print $3}'); do  
  sudo launchctl disable user/$(id -u)/$service 
  sudo launchctl disable system/$service  
done 

for service in $(sudo launchctl list | grep -i ReportMemoryException | awk '{print $3}'); do  
  sudo launchctl disable user/$(id -u)/$service 
  sudo launchctl disable system/$service  
done  

for service in $(sudo launchctl list | grep -i SubmitDiagInfo | awk '{print $3}'); do  
  sudo launchctl disable user/$(id -u)/$service 
  sudo launchctl disable system/$service  
done  


# Disable Wi-Fi diagnostics
for service in $(sudo launchctl list | grep -i wifianalyticsd | awk '{print $3}'); do  
  sudo launchctl disable user/$(id -u)/$service 
  sudo launchctl disable system/$service  
done  


# Disable netbiosd ( NetBIOS over TCP/IP )
for service in $(sudo launchctl list | grep -i netbiosd | awk '{print $3}'); do  
  sudo launchctl disable user/$(id -u)/$service 
  sudo launchctl disable system/$service  
done 




# sudo launchctl print system

sudo log config --reset

# Clear existing logs
sudo syslog -c 0  



components=$(sudo log show --predicate 'eventMessage CONTAINS "com."' --info --last 24h | \
             grep -o 'com\.[a-zA-Z0-9_]*\.[a-zA-Z0-9_]*' | \
             cut -d '.' -f 1-3 | sort | uniq)

for subsystem in $components; do
    sudo log config --subsystem "$subsystem" --mode "level:off, persist:off"
    status=$(sudo log config --subsystem "$subsystem" --status 2>/dev/null)
    echo "Status após alteração: $status"
done



# Desativa telemetria de processos
sudo defaults write /Library/Preferences/com.apple.apsd.plist APSLogLevel -int 0
sudo defaults write /Library/Preferences/com.apple.loginwindow.plist LogOutHook -string "/usr/bin/true"

# Reduce I/O and CPU overhead by disabling unused services
sudo launchctl disable user/$(id -u)/com.apple.spindump
sudo launchctl disable system/com.apple.spindump

# Remove agentes de telemetria
sudo rm -rf /usr/libexec/spindump/*

# Redirecionar logs para /dev/null
sudo ln -s /dev/null /var/log/system.log

# Limpar logs do sistema
sudo rm -rf /var/log/*
sudo rm -rf /var/db/diagnostics/*

# Limpar logs unificados e metadados
sudo rm -rf /private/var/db/diagnostics/*
sudo rm -rf /private/var/db/uuidtext/*

# Limpar logs de crash reports
sudo rm -rf /Library/Logs/DiagnosticReports/*
sudo rm -rf ~/Library/Logs/DiagnosticReports/*

# Limpar logs de instalação
sudo rm -rf /var/log/install/*

# Limpar cache de logs
sudo log erase --all

# Limpar logs de aplicativos específicos
sudo rm -rf ~/Library/Logs/*.log

# Limpar logs de atualizações do software
sudo rm -rf /Library/Updates/Logs/*

# Limpar logs de boot
sudo rm -rf /private/var/log/asl/*





# Remoção Completa do Microsoft AutoUpdate
# Parar serviços em execução
sudo launchctl bootout system "/Library/LaunchDaemons/com.microsoft.autoupdate.helper.plist"
sudo launchctl bootout gui/$(id -u) "/Library/LaunchAgents/com.microsoft.update.agent.plist"
sudo launchctl disable system/com.microsoft.autoupdate.helper

# Excluir arquivos do sistema
sudo rm -rf "/Library/Application Support/Microsoft/MAU2.0"
sudo rm -f /Library/LaunchAgents/com.microsoft.update.agent.plist
sudo rm -f /Library/LaunchDaemons/com.microsoft.autoupdate.helper.plist
sudo rm -f /Library/PrivilegedHelperTools/com.microsoft.autoupdate.helper

# Excluir preferências do usuário
rm -rf ~/Library/Preferences/com.microsoft.autoupdate*.plist
rm -rf ~/Library/Application\ Support/Microsoft\ AU\ Daemon

# Desative o carregamento do agente
sudo defaults write /Library/LaunchAgents/com.microsoft.update.agent.plist Disabled -bool YES
sudo defaults write /Library/LaunchAgents/com.microsoft.update.agent.plist RunAtLoad -bool NO

# Trave o arquivo para evitar alterações
sudo chflags schg /Library/LaunchAgents/com.microsoft.update.agent.plist

# Desative telemetria e verificações automáticas
defaults write com.microsoft.autoupdate2 'MAUFeedbackEnabled' -bool FALSE
defaults write com.microsoft.autoupdate2 'SendAllTelemetryEnabled' -bool FALSE
defaults write com.microsoft.autoupdate2 'StartDaemonOnAppLaunch' -bool FALSE



sudo purge

history -c



echo "Obtém a lista de subsistemas (daemons e services) do sistema usando launchctl."
subsystems=$(sudo launchctl print system | grep -oE 'com\.[a-zA-Z0-9._-]+' | sort | uniq)
for subsystem in $subsystems; do
    status=$(sudo log config --subsystem "$subsystem" --status 2>/dev/null)
    echo "Status: $status"
done



echo "Obtém a lista de Defaults Domains."
subsystems=$(sudo Defaults Domains | grep -oE 'com\.[a-zA-Z0-9._-]+' | sort | uniq)
for subsystem in $subsystems; do
    status=$(sudo log config --subsystem "$subsystem" --status 2>/dev/null)
    echo "Status: $status"
done



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
# Bloqueio de Telemetria e Rastreamento (Microsoft)
127.0.0.1 activity.windows.com          # Telemetry
127.0.0.1 data.microsoft.com            # Telemetry
127.0.0.1 telemetry.microsoft.com       # Telemetry
127.0.0.1 vortex.data.microsoft.com     # Telemetry
127.0.0.1 v10.vortex-win.data.microsoft.com # Telemetry
127.0.0.1 v20.vortex-win.data.microsoft.com # Telemetry
127.0.0.1 watson.microsoft.com          # Crash Reporting
127.0.0.1 settings-win.data.microsoft.com # Telemetry
127.0.0.1 feedback.windows.com          # Metrics
127.0.0.1 eu-mobile.events.data.microsoft.com # Analytics
127.0.0.1 us-mobile.events.data.microsoft.com # Analytics
127.0.0.1 mobile.pipe.aria.microsoft.com # Telemetry

# Publicidade e Trackers (Microsoft/Bing)
127.0.0.1 ads.msn.com                   # Advertising
127.0.0.1 bingads.microsoft.com         # Advertising
127.0.0.1 c.bing.com                    # Trackers
127.0.0.1 c.msn.com                     # Trackers
127.0.0.1 browser.events.data.msn.com   # Analytics

# Analytics e Métricas (Apple)
127.0.0.1 analytics.apple.com           # Analytics
127.0.0.1 metrics.apple.com             # Metrics
127.0.0.1 telemetry.apple.com           # Telemetry
127.0.0.1 radarsubmissions.apple.com    # Crash Reporting
127.0.0.1 api-glb-crashlytics.itunes.apple.com # Crash Reporting
127.0.0.1 crashes.iosapps.apple.com     # Crash Reporting

# Advertising (Google)
127.0.0.1 ads.google.com                # Advertising
127.0.0.1 adservice.google.*            # Advertising
127.0.0.1 doubleclick.net               # Advertising
127.0.0.1 googleadservices.com          # Advertising
127.0.0.1 pagead2.googlesyndication.com # Advertising
127.0.0.1 partnerad.l.doubleclick.net   # Advertising
127.0.0.1 ad.doubleclick.net            # Advertising

# Analytics e Tag Management (Google)
127.0.0.1 google-analytics.com          # Analytics
127.0.0.1 googletagmanager.com          # Tag Management
127.0.0.1 www.googletagservices.com     # Tag Management
127.0.0.1 ssl.google-analytics.com      # Analytics
127.0.0.1 app-measurement.com           # Analytics
127.0.0.1 beacon.google.com             # Analytics

# Facebook/Meta
127.0.0.1 graph.facebook.com            # Trackers
127.0.0.1 connect.facebook.net          # Trackers
127.0.0.1 pixel.facebook.com            # Trackers
127.0.0.1 tracking.facebook.com         # Trackers
127.0.0.1 ads.instagram.com             # Advertising
127.0.0.1 graph.instagram.com           # Trackers
127.0.0.1 logging.instagram.com         # Analytics
127.0.0.1 fbcdn-track.com               # Trackers

# Mozilla
127.0.0.1 telemetry.mozilla.org         # Telemetry
127.0.0.1 incoming.telemetry.mozilla.org # Telemetry
127.0.0.1 crash-stats.mozilla.com       # Crash Reporting

# Outras Plataformas
127.0.0.1 ads.yahoo.com                 # Advertising
127.0.0.1 ads.linkedin.com              # Advertising
127.0.0.1 ads.pinterest.com             # Advertising
127.0.0.1 analytics.tiktok.com          # Analytics
127.0.0.1 log-upload.tiktokv.com        # Telemetry
127.0.0.1 analytics.snapchat.com        # Analytics
127.0.0.1 ads.criteo.com                # Advertising
127.0.0.1 cdn.taboola.com               # Advertising

# Ferramentas de Terceiros
127.0.0.1 hotjar.com                    # Analytics
127.0.0.1 matomo.cloud                  # Analytics
127.0.0.1 scorecardresearch.com         # Analytics
127.0.0.1 quantserve.com                # Trackers
127.0.0.1 imrworldwide.com              # Trackers
127.0.0.1 optimizely.com                # A/B Testing
127.0.0.1 fullstory.com                 # Session Replay

# E-commerce e Outros
127.0.0.1 adsystem.amazon.com           # Advertising
127.0.0.1 fls-na.amazon.com             # Trackers
127.0.0.1 telemetry.adobe.com           # Telemetry
127.0.0.1 config.samsungads.com         # Advertising

# Additional Domains Added for Completeness
127.0.0.1 cdn.ampproject.org            # Trackers
127.0.0.1 stats.g.doubleclick.net       # Advertising
127.0.0.1 securepubads.g.doubleclick.net # Advertising
127.0.0.1 pubads.g.doubleclick.net      # Advertising
127.0.0.1 adserver.adtechus.com         # Advertising
127.0.0.1 adserver.adtech.de            # Advertising
127.0.0.1 trc.taboola.com               # Trackers
127.0.0.1 cdn.segment.com               # Analytics
127.0.0.1 api.mixpanel.com              # Analytics
127.0.0.1 events.outbrain.com           # Trackers

# OneDrive Client for macOS 12.x Monterey EOL Workaround
127.0.0.1 oneclient.sfx.ms

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


echo "Resetting LaunchServices database by removing file associations and rebuilding"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user

echo "Flushing the dscacheutil cache can help manage space and free up memory for other processes..."

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
