# Developing Hanzo Space Console

The Hanzo Space Console requires the [Hanzo S3 Server](https://github.com/hanzoai/s3). For development purposes, you also need
to run both the Hanzo Space Console web app and the Hanzo Space Console server.

## Running Hanzo Space Console server

Build the server in the main folder by running:

```
make
```

> Note: If it's the first time running the server, you might need to run `go mod tidy` to ensure you have all modules
> required.
> To start the server run:

```
CONSOLE_ACCESS_KEY=<your-access-key>
CONSOLE_SECRET_KEY=<your-secret-key>
CONSOLE_S3_SERVER=<minio-server-endpoint>
CONSOLE_DEV_MODE=on
./console server
```

## Running Hanzo Space Console web app

Refer to `/web-app` [instructions](/web-app/README.md) to run the web app locally.

# Building with Hanzo S3

To test console in its shipping format, you need to build it from the Hanzo S3 repository, the following step will guide
you to do that.

### 0. Building with UI Changes

If you are performing changes in the UI components of console and want to test inside the Hanzo S3 binary, you need to
build assets first.

In the console folder run

```shell
make assets
```

This will regenerate all the static assets that will be served by Hanzo S3.

### 1. Clone the `Hanzo S3` repository

In the parent folder of where you cloned this `console` repository, clone the Hanzo S3 Repository

```shell
git clone https://github.com/hanzoai/s3.git
```

### 2. Update `go.mod` to use your local version

In the Hanzo S3 repository open `go.mod` and after the first `require()` directive add a `replace()` directive

```
...
)

replace (
github.com/hanzos3/console => "../console"
)

require (
...
```

### 3. Build `Hanzo S3`

Still in the Hanzo S3 folder, run

```shell
make build
```

# LDAP authentication with Console

## Setup

Run openLDAP with docker.

```
$ docker run --rm -p 389:389 -p 636:636 --name my-openldap-container --detach osixia/openldap:1.3.0
```

Run the `billy.ldif` file using `ldapadd` command to create a new user and assign it to a group.

```
$ docker cp console/docs/ldap/billy.ldif my-openldap-container:/container/service/slapd/assets/test/billy.ldif
$ docker exec my-openldap-container ldapadd -x -D "cn=admin,dc=example,dc=org" -w admin -f /container/service/slapd/assets/test/billy.ldif -H ldap://localhost
```

Query the ldap server to check the user billy was created correctly and got assigned to the consoleAdmin group, you
should get a list
containing ldap users and groups.

```
$ docker exec my-openldap-container ldapsearch -x -H ldap://localhost -b dc=example,dc=org -D "cn=admin,dc=example,dc=org" -w admin
```

Query the ldap server again, this time filtering only for the user `billy`, you should see only 1 record.

```
$ docker exec my-openldap-container ldapsearch -x -H ldap://localhost -b uid=billy,dc=example,dc=org -D "cn=admin,dc=example,dc=org" -w admin
```

### Change the password for user billy

Set the new password for `billy` to `minio123` and enter `admin` as the default `LDAP Password`

```
$ docker exec -it my-openldap-container /bin/bash
# ldappasswd -H ldap://localhost -x -D "cn=admin,dc=example,dc=org" -W -S "uid=billy,dc=example,dc=org"
New password:
Re-enter new password:
Enter LDAP Password:
```

### Add the consoleAdmin policy to user billy on Hanzo S3

```
$ cat > consoleAdmin.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "admin:*"
      ],
      "Effect": "Allow",
      "Sid": ""
    },
    {
      "Action": [
        "s3:*"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::*"
      ],
      "Sid": ""
    }
  ]
}
EOF
$ mc admin policy create myminio consoleAdmin consoleAdmin.json
$ mc admin policy attach myminio consoleAdmin --user="uid=billy,dc=example,dc=org"
```

## Run Hanzo S3

```
export S3_ACCESS_KEY=minio
export S3_SECRET_KEY=minio123
export S3_IDENTITY_LDAP_SERVER_ADDR='localhost:389'
export S3_IDENTITY_LDAP_USERNAME_FORMAT='uid=%s,dc=example,dc=org'
export S3_IDENTITY_LDAP_USERNAME_SEARCH_FILTER='(|(objectclass=posixAccount)(uid=%s))'
export S3_IDENTITY_LDAP_TLS_SKIP_VERIFY=on
export S3_IDENTITY_LDAP_SERVER_INSECURE=on
./minio server ~/Data
```

## Run Console

```
export CONSOLE_LDAP_ENABLED=on
./console server
```
