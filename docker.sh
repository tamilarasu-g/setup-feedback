#!/usr/bin/bash

#Check if the script is executed using root

if [ $EUID -ne 0 ]
then
	echo "Please execute the script using root !!"
fi

#Exit Status Function
exit_status()
{
    if [[ "${?}" -ne 0 ]]
    then
        echo "$1"
        exit 1
    else
	echo "$2"
    fi
}

# Create the log file

touch log.txt

exit_status "Could not create the log file !!"


# Download Docker Script

echo "-----------------------------------------------------------------------------"

echo "Downloading Docker Install Script"

echo "-----------------------------------------------------------------------------"

curl -fsSL https://get.docker.com -o get-docker.sh

exit_status "Could not download the Docker script !!" "Downloaded the script successfully"


# Execute the Docker Install Script

echo "-----------------------------------------------------------------------------"

echo "Executing Docker Install Script !!"

echo "-----------------------------------------------------------------------------"

sh get-docker.sh

exit_status "Could not Install Docker !!" "Docker Installed Successfully....Please Logout"

