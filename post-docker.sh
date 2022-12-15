# Check if the script is executed by the root user

if [ "$EUID" -ne 0 ]
  then echo "Please run as root" >> log.txt
  exit 1
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

# Variables
IP="$(hostname -I | awk '{print $1}')"
exit_status "No IP assigned !!" "IP found"

# Display function

display()
{
	echo "------------------------------------------------------------------------------------------"
	echo "$1"

}


# Put Docker in Swarm mode

display "Initiating Docker Swarm Mode"

docker swarm init --advertise-addr ${IP}

exit_status "Could not initiate Docker swarm mode !!" "Docker swarm mode initiated."

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

exit_status "Could not pull the mongodb image !!" "MongoDB image pulled succesfully."

#-----------------------------------------------------------------------------------

# Replace the credentials for mongodb

export $(grep -v '^#' ./mongodb/.env | xargs -d '\n')

sed -i -e "s|ADMIN_USER|$ADMIN_USER|g" ./mongodb/add-users.sh
sed -i -e "s|ADMIN_PASSWD|$ADMIN_PASSWD|g" ./mongodb/add-users.sh
sed -i -e"s|DB_USER|$DB_USER|g" ./mongodb/add-users.sh
sed -i -e "s|DB_PASSWD|$DB_PASSWD|g" ./mongodb/add-users.sh
sed -i -e "s|DB|$DB|g" ./mongodb/add-users.sh


#-----------------------------------------------------------------------------------

# Create keyfile for Replicaset

openssl rand -base64 700 > ./mongodb/file.key

chmod 400 ./mongodb/file.key

#-----------------------------------------------------------------------------------

#Start containers for mongodb

display "Starting containers for mongodb"

docker compose -f ./mongodb/docker-compose.yml up -d

exit_status "Could not start the containers for MongoDB"

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

docker stack deploy -c ./server/docker-compose.yml backend

exit_status "Could not create a service for server" "Service created successfully for server."

#-----------------------------------------------------------------------------------

# Create the service for client

display "Creating the service for client"

docker stack deploy -c ./client/docker-compose.yml frontend

exit_status "Could not create the service for client" "Service created successfully for client"

exit 0
