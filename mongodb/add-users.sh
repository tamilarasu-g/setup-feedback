#!/usr/bin/bash

mongosh <<EOF

use admin

db.createUser(
  {
    user: "ADMIN_USER",
    pwd: "ADMIN_PASSWD",
    roles: [
      { role: "root", db: "admin" }
    ]
  }
);

db.auth("ADMIN_USER","ADMIN_PASSWD")

db.createUser(
        {
            user: "DB_USER",
            pwd: "DB_PASSWD",
            roles: [
                {
                    role: "readWrite",
                    db: "DB"
                }
            ]
        }
);
