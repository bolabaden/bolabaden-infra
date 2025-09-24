#!/bin/bash

echo "**********************************************************"
echo "******** Premiumize.me OpenVPN CLI install script ********"
echo "********        Version 1.0.1 - 01.03.2022        ********"
echo "**********************************************************"
echo && sleep 1
echo "This script will perform the installation and configuration of OpenVPN automatically." && sleep 1
echo "You can also use this script to update the configuration files." && sleep 1
echo "Please pay attention to the output of the script, as input is required!" && sleep 1
echo "If the installation using this script fails, please contact customer service and provide the full console output."
echo && sleep 1
while true
do
	echo "Do you understand that? [Y/n]"
	read confirm
	case $confirm in
            [yY][eE][sS]|[yY])
                  echo "Starting installation...."
                  echo
                  sleep 1
                  break
                  ;;
            [nN][oO]|[nN])
                  echo "Exiting script..."
		          exit
                  break
                  ;;
            *)
                  echo "Invalid input...please try again!"
		          echo && sleep 1
                  ;;
      esac
done

#Update package sources list
echo "Updating package sources list..." && sleep 1
apt-get update -y
echo && sleep 1

#Install wget
echo "Installing or updating wget..." && sleep 1
apt-get install wget -y
echo && sleep 1

#Install openvpn
echo "Installing or updating unzip..." && sleep 1
apt-get install unzip -y
echo && sleep 1

#Install openvpn
echo "Installing or updating OpenVPN..." && sleep 1
apt-get install openvpn -y
echo && sleep 1

#Download config files
echo "Downloading configuration files..." && sleep 1
wget https://www.premiumize.me/static/tutorials/vpn/openvpn/linux/vpn-all.premiumize.me-generic.zip
echo && sleep 1 

#Unzip and delete zip file
echo "Unzip configuration files..." && sleep 1
unzip -o vpn-all.premiumize.me-generic.zip -d /etc/openvpn/
echo && sleep 1
echo "Remove zip file..." && sleep 1
rm -v vpn-all.premiumize.me-generic.zip
echo && sleep 1

#Check if credentials file exists
echo "Checking if credentials file already exists..."
if test -f "/etc/openvpn/premiumize_credentials";
then
  #Select: create new file or use existing file
  echo "You already have a credentials file for Premiumize.me in your OpenVPN folder. You have the following options:"
  echo "1) Enter new credentials"
  echo "2) Use existing credentials"
  echo "Please select [1-2]"
  read credentials_select
else
  echo "File does not exist yet, create new one..."
  credentials_select=1
fi
while true
do
        case $credentials_select in
            1)
              	  #Get credentials and save them in file
                  echo
                  echo "Please enter your Premiumize.me customer number and API key below. You can find it here: https://www.premiumize.me/account"
                  echo
                  echo "Please enter your customer-id: "
                  read id
                  echo "Please enter your API-Key: "
                  read key
                  echo
                  echo "Saving credentials in file..."
                  printf '%d\n%s' "$id" "$key" > /etc/openvpn/premiumize_credentials
                  break
                  ;;
            2)
                  echo
                  echo "Using existing file..."
                  break
                  ;;
            *)
                  echo "Invalid input...please try again!"
                  echo && sleep 1
                  echo "Please select [1-2]"
                  read credentials_select
                  ;;
      esac
done
echo && sleep 1

#Updating config files for authentication with file
echo "Updating configuration files for file authentication..." && sleep 1
for config in /etc/openvpn/vpn-*.premiumize.me.ovpn
do
	echo "Updating: $config"
	sed -i 's/auth-user-pass/auth-user-pass \/etc\/openvpn\/premiumize_credentials/g' $config
done
echo && sleep 1

#Create services
echo "You now have the option to create services automatically."
echo "When you create the services, you can simply start and stop the VPN connection as a service (e.g. service vpn-XX.premiumize.me start)."
echo "Optionally, you can also start a VPN connection at system startup."
echo "If you do not want to do that, you can of course still start the VPN connection."
echo
echo "You have the following options:"
echo "1) Create a service for all VPN servers"
echo "2) Create a service for a specific VPN server"
echo "3) Do not create services"
while true
do
        echo "Please select [1-3]"
        read select_service
	    echo
        case $select_service in
            3) #Instructions for manual start
                  echo "Skipping service creation..."
                  echo && sleep 1
                  echo "You can now start your VPN connection as follows."
                  echo "Do not forget to select the correct configuration at startup!"
                  echo
                  echo "sudo nohup openvpn --config /etc/openvpn/vpn-XX.premiumize.me.ovpn &"
                  echo
                  echo "To disconnect, use: sudo killall openvpn"
                  echo
                  break
                  ;;

            2) #Select config and continue with 1 (no break!)
                  while true
                  do
                        echo "Please select one configuration from the list:"
                        echo && sleep 1
                        for service in /etc/openvpn/vpn-*.premiumize.me.ovpn
                        do
                            echo $(basename "$service")
                        done
                        echo && sleep 1
                        echo "Please enter a configuration name: "
                        read path
                        if test -f "/etc/openvpn/$path"; then break; else echo "Could not find configuration file. Try again..."; fi
                  done
                  path="/etc/openvpn/$path"
                  echo && sleep 1
                  ;&

            1) #Creating services from 2) or for all configs
                  echo "Creating service(s)..."
                  echo && sleep 1
		          if [ $select_service -eq 1 ]; then path="/etc/openvpn/vpn-*.premiumize.me.ovpn"; fi
                  for service in $path
                  do
                          name=$(basename -s ".ovpn" "$service")
                          echo "Creating service: $name.service"
                          txt="[Unit]\n"
                          txt+="Description=Premiumize.me OpenVPN CLI $name\n"
                          txt+="After=multi-user.target\n\n"
                          txt+="[Service]\n"
                          txt+="Type=idle\n"
                          txt+="ExecStart=/usr/sbin/openvpn --config $service\n\n"
                          txt+="[Install]\n"
                          txt+="WantedBy=multi-user.target"
                          printf "$txt" > "/etc/systemd/system/$name.service"
                          echo "Setting file permission..."
                          chmod 644 "/etc/systemd/system/$name.service"
                          echo
                  done
                  echo && sleep 1
                  echo "Reloading systemctl daemon..."
                  sleep 1
                  systemctl daemon-reload
                  echo && sleep 1
                  echo "Once the script is completed, you can establish a VPN connection as follows:"
                  echo
                  echo "service vpn-XX.premiumize.me start (-> replace XX by country code)"
                  echo && sleep 1
                  echo "You can establish a VPN connection automatically when you start the operating system."
                  echo
                  while true
                  do
                          echo "Do you want that? [Y/n]"
                          read autostart
                          case $autostart in
                              [yY][eE][sS]|[yY])
                                    while true
                                    do
                                          echo "Please select one service from the list:"
                                          echo
                                          for service in /etc/systemd/system/vpn-*.premiumize.me.service
                                          do
                                                  echo $(basename "$service")
                                          done
                                          echo
                                          echo "Please enter a service  name: "
                                          read path
                                          if test -f "/etc/systemd/system/$path"; then break; else echo "Could not find service file. Try again..."; fi
                                    done
                                    echo && sleep 1
                                    echo "Setting up autostart..."
                                    sleep 1
                                    systemctl enable "$path"
                                    echo && sleep 1
                                    echo "After the script is finished, you can reboot your system. After the restart you can check the status of the service as follows:"
                                    echo
                                    echo "systemctl status $path"
                                    echo && sleep 1
                                    break
                                    ;;
                              [nN][oO]|[nN])
                                    echo "Skipping autostart setup..."
                                    echo && sleep 1
                                    exit
                                    break
                                    ;;
                              *)
                                    echo "Invalid input...please try again!"
                                    echo && sleep 1
                                    ;;
                        esac
                  done
                  break
                  ;;
            *)
                  echo "Invalid input...please try again!"
                  echo && sleep 1
                  ;;
      esac
done

while true
do
        echo "Do you want to install 'elinks' to check the connection? [Y/n]"
        read confirm
        case $confirm in
            [yY][eE][sS]|[yY])
                  echo "Installing elinks...."
                  sleep 1
                  apt-get install elinks -y
                  echo && sleep 1
                  echo "After you have established the VPN connection, you can check the connection using the following command:"
                  echo
                  echo "elinks https://www.premiumize.me/checkvpn"
                  echo && sleep 1
                  break
                  ;;
            [nN][oO]|[nN])
                  echo "Skipping elinks installation..."
		          echo && sleep 1
                  break
                  ;;
            *)
                  echo "Invalid input...please try again!"
                  echo && sleep 1
                  ;;
      esac
done
echo "The installation and configuration is now complete."
echo && sleep 1
echo "Exiting now..."
