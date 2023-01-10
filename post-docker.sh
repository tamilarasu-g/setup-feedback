#!/usr/bin/bash

# Check if the script is executed by the root user

#if [ "$EUID" -ne 0 ]
#  then echo "Please run as root" >> log.txt
#  exit 1
#fi


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

# Variables
IP="$(hostname -I | awk '{print $1}')"
exit_status "No IP assigned !!" "IP found"
CURRENT_WORKING_DIRECTORY=$(pwd)

# Display function

display()
{
	echo "------------------------------------------------------------------------------------------"
	echo "$1"

}


# Put Docker in Swarm mode

display "Initiating Docker Swarm Mode"

if [ "$(docker info | grep Swarm | sed 's/Swarm: //g')" == " inactive" ]
then 
	docker swarm init --advertise-addr ${IP}
	exit_status "Could not initiate Docker swarm" "Docker Swarm Mode Inititated."
elif [ "$(docker info | grep Swarm | sed 's/Swarm: //g')" == " active" ]
then
	echo "Docker Swarm Mode already active."
else
	echo "Docker swarm mode is not ready. Please check the state of Docker swarm."
	exit 1
fi

#-----------------------------------------------------------------------------------

# Pull the server image

display "Pulling server image"

docker compose -f ./server/docker-compose.yml pull

exit_status "Could not pull the server image !!" "Server image pulled successfully"

#-----------------------------------------------------------------------------------

# Pull the client image

display "Pulling client image"

docker compose -f ./client/docker-compose.yml pull

exit_status "Could not pull client image !!" "Client image pulled successfully"

#-----------------------------------------------------------------------------------

# Pull the mongodb image 

display "Pulling mongodb image"

docker compose -f ./mongodb/docker-compose.yml pull

exit_status "Could not pull the mongodb image !!" "MongoDB image pulled successfully."

#-----------------------------------------------------------------------------------

# Copy the updateScript file to /usr/bin/

chmod +x updateScript

sudo cp updateScript /usr/bin/

exit_status "Could not copy updateScript to /usr/bin/" "Copied updateScript successfully"

# Copy the execpipe file to /usr/bin/

sed -i -e "s|DIR|$CURRENT_WORKING_DIRECTORY|g" ./execpipe

exit_status "Could not replace the $CURRENT_WORKING_DIRECTORY in execpipe"

chmod +x execpipe

sudo cp execpipe /usr/bin/

exit_status "Could not copy the execpipe to /usr/bin/" "Copied execpipe successfully"

# Start the pipe process for listening

/usr/bin/execpipe > /dev/null 2>&1 & 

# Setup the cronjob for the pipe process to persist after reboot

(crontab -l; echo "@reboot /usr/bin/execpipe") | sort -u | crontab -

exit_status "Could not add the cronjob entry" "Cron job added successfully"

# Check for presence of requirements.txt file

if [[ ! -f ./requirements.txt ]]
then
    exit_status "The requirements.txt file does not exist"
fi

# Unset any previously defined ENV Variables

while read arguments
do
    if [[ $arguments =~ ^[[:upper:]]+$ || $arguments =~ "_" ]]
    then
        unset "$arguments"
    else
        if ! command -v "$arguments" &> /dev/null
        then
            echo "$arguments command does not exist"
            exit 1
        fi
    fi
done < ./requirements.txt

# Check for the presence of all ENV files

files=("./server/.env" "./client/.env" "./mongodb/.env")

for file in ${files[@]}
do
    if [[ ! -f $file ]]
    then
        echo "The $file does not exist" 
    else
        echo "$file exists"
        if [[ $file == *.env ]]
        then
            export $(grep -v '^#' $file | xargs -d '\n')
            exit_status "Could not export the env variables of $file." "Exported the variables in $file successfully"
        fi
    fi
done


# Check if all the required variables are set

while read env_variable
do
    if [[ $env_variable =~ ^[[:upper:]]+$ ]]
    then
        if [[ -z "$env_variable" ]]
        then
            echo "$env_variable is not defined"
            exit 1
        fi
    fi
done < requirements.txt

#-----------------------------------------------------------------------------------


# Replace the credentials for mongodb

ADD_USERS_FILE="./mongodb/add-users.sh"

sed -i -e "s|ADMIN_USER|$ADMIN_USER|g" $ADD_USERS_FILE 
sed -i -e "s|ADMIN_PASSWD|$ADMIN_PASSWD|g" $ADD_USERS_FILE
sed -i -e"s|DB_USER|$DB_USER|g" $ADD_USERS_FILE
sed -i -e "s|DB_PASSWD|$DB_PASSWD|g" $ADD_USERS_FILE
sed -i -e "s|DB|$DB|g" $ADD_USERS_FILE


#-----------------------------------------------------------------------------------

# Create keyfile for Replicaset

openssl rand -base64 700 > ./mongodb/file.key

chmod 400 ./mongodb/file.key

exit_status "Could not create/modify the permissions for key file" "Key file for mongodb created and modified successfully"

#-----------------------------------------------------------------------------------

#Start containers for mongodb

display "Starting containers for mongodb"

docker compose -f ./mongodb/docker-compose.yml up -d

exit_status "Could not start the containers for MongoDB" "MongoDB containers started successfully"

#-----------------------------------------------------------------------------------

# Initiate Replicaset in Mongodb

display "Initiating Replicaset in MongoDB"

docker container exec -it mongodb-mongo1-1 sh /scripts/rs-init.sh

exit_status "Could not initiate Replicaset !!" "Replicaset inititated successfully."

#-----------------------------------------------------------------------------------

# Enable Authentication and Authorization in Mongodb

display "Enabling authentication and authorization"

docker container exec -it mongodb-mongo1-1 sh /scripts/add-users.sh

exit_status "Could not enable authentication and authorization" "Enabled authentication and authorization"


#-----------------------------------------------------------------------------------

# Create the service for server

display "Creating service for Server"

touch ./server/log.txt

exit_status "Could not create the log file for server" "Log file for server created successfully"

mkfifo ./server/mypipe

exit_status "Could not create the pipe" "Pipe created successfully"

docker stack deploy -c ./server/docker-compose.yml backend

exit_status "Could not create a service for server" "Service created successfully for server."

#-----------------------------------------------------------------------------------

# Create the service for client

display "Creating the service for client"

docker stack deploy -c ./client/docker-compose.yml frontend

exit_status "Could not create the service for client" "Service created successfully for client"


#-----------------------------------------------------------------------------------

# Setup NGINX

display "Setting up NGINX"

sudo apt-get update

exit_status "Could not update repositories." "Updated repositories successfully"

sudo apt-get install nginx-full certbot python3-certbot-nginx -y

exit_status "Could not install the required packages" "Installed the required packages successfully"

exit 0
