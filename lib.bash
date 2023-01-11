set -eu
set -o pipefail

#> PROCESS CLI ARGS >#
force_destruction=""
if [[ ${1-} = --force ]]; then
  force_destruction="confirmed"
  shift
fi
#< PROCESS CLI ARGS <#

testPrefix="$(basename "$0")"
log() {
  echo "[$testPrefix] $*"
}
warn() {
  echo
  log "!!! WARN !!! $*"
  echo
}

check_for_dependencies() {
  if ! command -v docker-compose >/dev/null; then
    log "!!!"
    log "!!! docker-compose not found!"
    log "!!!"
    exit 1
  fi
}

configure_environment() {
  baseDir="$(pwd)"

  baseRepo=https://github.com/alxndrsn/odk-central.git # TODO this will need to be updated to getodk/central
  initialVersion="${INITIAL_VERSION-v1.5.3-with-extra-debug}"
  targetVersion="upgrade-postgres-next"
  # include a nonce in the test directory, as we will not own the postgres data
  # directory by the end of the test.  An alternative would be to `sudo` when
  # removing the test directory, but better to not require extra permissions.
  testDir="tmp/$initialVersion-to-$targetVersion/$(date +%s)"

  # a bunch of env vars for containers
  export SYSADMIN_EMAIL=no-reply@getodk.org
  export DOMAIN=local
  export HTTP_PORT=18080
  export HTTPS_PORT=18443
  export SSL_TYPE=selfsign

  log "Cleaning up test directory..."
  rm -rf "$testDir" || true
  mkdir -p "$testDir"

  log "Creating test directory..."
  cd "$testDir"
  # disable annoying git messages
  git config --local advice.detachedHead false
}

clone_central_repo() {
  log "Cloning odk-central git repo ($baseRepo)..."
  # I suspect we -have- to maintain the `central` name as per https://github.com/getodk/central/issues/300
  git clone "$baseRepo" central # fetch the whole repo so that git describe --tags works predictably
  cd central
  touch allow-postgres-database-version-update
  git_checkout "$initialVersion"
}

git_checkout() {
  log "Checking out '$1'..."
  git checkout "$1"
  git submodule init
  git submodule update -i --jobs 16
  log "Checked out '$1':"
  git show --pretty=oneline --summary
}

rebuild_and_restart_containers() {
  rebuild_containers
  restart_containers
  wait_for_service_container
}

rebuild_containers() {
  log "Rebuilding containers..."
  dev_speed_patch
  docker-compose build
  dev_speed_unpatch
  log "Containers rebuilt OK."
}

restart_containers() {
  log "Restarting containers..."
  docker-compose stop
  docker-compose up --remove-orphans --detach
  log "Containers restarted OK."
}

check_for_dirty_docker() {
  log "\nChecking for existing containers..."
  if [[ "$(docker-compose ps | tail -n+3 | wc -l | xargs)" != "0" ]]; then # xargs for BSD-compatability
    warn "docker-compose HAS ALREADY CREATED CONTAINERS ON THIS SYSTEM:"
    docker-compose ps
    warn "THESE CONTAINERS AND THEIR VOLUMES WILL BE DESTROYED!"

    confirm_if_required "OK, containers and volumes will be destroyed..."

    log "Cleaning docker-compose...\n"
    docker-compose down --remove-orphans --volumes
    echo
  fi

  log "\nChecking for existing docker volumes..."
  if [[ "$(docker volume ls -f name=central_pg14 | tail -n+2 | wc -l)" != "0" ]]; then
    warn "docker HAS ALREADY CREATED VOLUMES ON THIS SYSTEM:"
    docker volume ls -f name=central_pg14
    warn "THESE VOLUMES WILL BE DESTROYED!"

    confirm_if_required "OK, volumes will be destroyed..."

    log "Cleaning docker volumes...\n"
    docker volume rm central_pg14
    echo
  fi
}

exec_in_service_container() {
  local scriptName="$1"
  # failure should not kill the script - leave error handling up to the caller
  docker exec -i central_service_1 node -e "$(cat "$baseDir/$scriptName")" || true
}

dev_speed_patch() {
  # (temporary?) have for faster development
  tail -n+8 nginx.dockerfile | sed /intermediate/d > nginx.dockerfile.tmp
  mv nginx.dockerfile.tmp nginx.dockerfile
}
dev_speed_unpatch() {
  git checkout -- nginx.dockerfile
}

confirm_postgres_version() {
  local expectedVersion="$1"
  log "[confirm_postgres_version] Checking for postgres version: '$expectedVersion'..."
  local actualVersion
  local retries=0
  while true; do
    actualVersion="$(exec_in_service_container get-postgres-version.js)"
    if [[ "$actualVersion" = "$expectedVersion" ]]; then
      log "[confirm_postgres_version] Postgres version confirmed: $expectedVersion"
      exit 0
    elif [[ "$actualVersion" = "" ]]; then
      if [[ "$retries" -lt 5 ]]; then
        log "[confirm_postgres_version] Retrying..."
        (( ++retries ))
        sleep 2
      else
        log "[confirm_postgres_version] !!!"
        log "[confirm_postgres_version] !!! Retry count exceeded !!!"
        log "[confirm_postgres_version] !!!"
        exit 1
      fi
    else
      log "[confirm_postgres_version] !!!"
      log "[confirm_postgres_version] !!! Incorrect postgres version !!!"
      log "[confirm_postgres_version] !!!   Expected: $expectedVersion"
      log "[confirm_postgres_version] !!!    but got: $actualVersion"
      log "[confirm_postgres_version] !!!"
      exit 1
    fi
  done
}

confirm_seed_data() {
  local isOk
  isOk="$(exec_in_service_container get-migration-seed.js)"
  if [[ "$isOk" = "true" ]]; then
    log "[confirm_seed_data] Seed data OK!"
  else
    log "[confirm_seed_data] !!!"
    log "[confirm_seed_data] !!! Incorrect migration seed !!!"
    log "[confirm_seed_data] !!!   Expected: true"
    log "[confirm_seed_data] !!!    but got: $isOk"
    log "[confirm_seed_data] !!!"
    exit 1
  fi
}

confirm_backend_running_ok() {
  local response_code
  for _ in {0..180}; do
    response_code="$(curl -k -s -o /dev/null -w "%{http_code}" "https://localhost:$HTTPS_PORT/v1/sessions" --data '{"email":"doesntexist@example.com","password":"doesntmatter"}' --header 'Content-Type: application/json' || true)"
    if [[ "$response_code" = 401 ]]; then
      log "[confirm_backend_running_ok] Looks OK!"
      return
    fi
    log "[confirm_backend_running_ok] Backend returned unexpected response: $response_code.  Sleeping..."
    sleep 1
  done
  log "[confirm_backend_running_ok] !!!"
  log "[confirm_backend_running_ok] !!! Backend did not start."
  log "[confirm_backend_running_ok] !!!"
  exit 1
}

wait_for_service_container() {
  log "[wait_for_service_container] Waiting for service container to start..."
  # ...and for the local.json config file to have been created
  for _ in {0..180}; do
    dbHost="$(exec_in_service_container get-db-host.js)"
    if [[ "$dbHost" = postgres ]] || [[ "$dbHost" = postgres-14 ]]; then
      log "[wait_for_service_container] Database config looks OK!"
      return
    fi
    log "[wait_for_service_container] Database config hasn't updated.  Sleeping..."
    sleep 1
  done
  warn "[wait_for_service_container] !!!"
  warn "[wait_for_service_container] !!! Database config never updated."
  warn "[wait_for_service_container] !!!"
  exit 1
}

confirm_if_required() {
  local confirmed_message="$1"
  if [[ "$force_destruction" != "confirmed" ]]; then
    read -r -n1 -p "Continue (y/n)? " choice
    echo
    case "$choice" in
      y|Y) echo "$confirmed_message" ;;
      *  ) log "Aborted."; exit 1 ;;
    esac
  fi
}

setup_standard() {
  check_for_dependencies
  configure_environment
  clone_central_repo
  check_for_dirty_docker

  log "Starting $initialVersion..."
  dev_speed_patch
  docker-compose build
  dev_speed_unpatch
  docker-compose up --remove-orphans --detach

  wait_for_service_container

  confirm_postgres_version 9.6
  confirm_backend_running_ok

  log "Seeding database..."
  exec_in_service_container seed-db.js
  confirm_seed_data
  confirm_postgres_version 9.6
}
