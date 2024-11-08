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