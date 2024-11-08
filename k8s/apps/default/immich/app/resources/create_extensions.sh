#!/usr/bin/env bash

# This is most commonly set to the user 'postgres'
export INIT_POSTGRES_SUPER_USER=${INIT_POSTGRES_SUPER_USER:-postgres}
export INIT_POSTGRES_PORT=${INIT_POSTGRES_PORT:-5432}

if [[ -z "${INIT_POSTGRES_HOST}"       ||
      -z "${INIT_POSTGRES_SUPER_PASS}" ||
      -z "${INIT_POSTGRES_USER}"       ||
      -z "${INIT_POSTGRES_PASS}"       ||
      -z "${INIT_POSTGRES_DBNAME}"
]]; then
    printf "\e[1;32m%-6s\e[m\n" "Invalid configuration - missing a required environment variable"
    [[ -z "${INIT_POSTGRES_HOST}" ]]       && printf "\e[1;32m%-6s\e[m\n" "INIT_POSTGRES_HOST: unset"
    [[ -z "${INIT_POSTGRES_SUPER_PASS}" ]] && printf "\e[1;32m%-6s\e[m\n" "INIT_POSTGRES_SUPER_PASS: unset"
    [[ -z "${INIT_POSTGRES_USER}" ]]       && printf "\e[1;32m%-6s\e[m\n" "INIT_POSTGRES_USER: unset"
    [[ -z "${INIT_POSTGRES_PASS}" ]]       && printf "\e[1;32m%-6s\e[m\n" "INIT_POSTGRES_PASS: unset"
    [[ -z "${INIT_POSTGRES_DBNAME}" ]]     && printf "\e[1;32m%-6s\e[m\n" "INIT_POSTGRES_DBNAME: unset"
    exit 1
fi

# These env are for the psql CLI
export PGHOST="${INIT_POSTGRES_HOST}"
export PGUSER="${INIT_POSTGRES_SUPER_USER}"
export PGPASSWORD="${INIT_POSTGRES_SUPER_PASS}"
export PGPORT="${INIT_POSTGRES_PORT}"

until pg_isready; do
    printf "\e[1;32m%-6s\e[m\n" "Waiting for Host '${PGHOST}' on port '${PGPORT}' ..."
    sleep 1
done

printf "\e[1;32m%-6s\e[m\n" "Creating extensions..."
psql --command "CREATE EXTENSION cube;"
psql --command "CREATE EXTENSION earthdistance;"
psql --command "CREATE EXTENSION vectors;"