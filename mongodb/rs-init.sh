#!/bin/bash

mongosh <<EOF
var config = {
    "_id": "myrepl",
    "version": 1,
    "members": [
        {
            "_id": 1,
            "host": "mongodb-mongo1-1:27017",
            "priority": 3
        },
        {
            "_id": 2,
            "host": "mongodb-mongo2-1:27017",
            "priority": 2
        },
        {
            "_id": 3,
            "host": "mongodb-mongo3-1:27017",
            "priority": 1
        }
    ]
};
rs.initiate(config, { force: true });
rs.status();
EOF
