#!/bin/sh

# Declare

GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

levelsuffixes="_nether _the_end"

# Functions

container_sleep() {
  echo "Sleeping.."
  # Spin until we receive a SIGTERM (e.g. from `docker stop`)
  trap 'exit 143' SIGTERM # exit = 128 + 15 (SIGTERM)
  tail -f /dev/null & wait ${!}
}

spigot_run() {
  echo "Running spigot.."
  java $JAVA_OPTS -jar spigot.jar
}

level_links_rm() {
  rm "$1"
  for suffix in $levelsuffixes; do
    rm "$1${suffix}";
  done
}

level_data_mv() {
  mv "$1" "$2"
  for suffix in $levelsuffixes; do
    mv "$1${suffix}" "$2${suffix}";
  done
}

level_data_ln() {
  ln -s "$1" "$2"
  for suffix in $levelsuffixes; do
    ln -s "$1${suffix}" "$2${suffix}";
  done
}

level_data_rm() {
  rm -rf "$1"
  for suffix in $levelsuffixes; do
    rm -rf "$1${suffix}";
  done
}

level_data_backup() {
  local backupfolder="$1"
  local levelname=$(level_name_get)
  local backupfilename="$(date '+%Y%m%d%H%M%S')_${levelname}.tar.gz"
  echo -e "writing backup for level ${YELLOW}${levelname}${NC} in ${backupfilename} to $1 ..."
  local tar_result
  local tar_status=-1
  tar_result=$(cd "${SPIGOT_LEVELDATA}" && tar -chzf "${backupfolder}/${backupfilename}" "${levelname}" "${levelname}_nether" "${levelname}_the_end")
  tar_status=$?
  if [ ${tar_status} != 0 ] ; then
    echo -e "${RED}Backup failed!${NC} status: ${tar_status}, result: ${tar_result}"
  else
    echo -e "${GREEN}Backup done!${NC}"
  fi
}

level_data_restore() {
  local restorefrom="$1"
  local restoreto="$2"
  echo "restoring leveldata $1 to $2 ..."
  local restorefromlevel="$(tar -tf "${restorefrom}" | grep -e ^[^/_]*/$)"
  restorefromlevel=${restorefromlevel%/}
  echo -e "level to restore is: ${YELLOW}${restorefromlevel}${NC}"
  level_data_rm "${restoreto}/${restorefromlevel}"
  local tar_result
  local tar_status=-1
  tar_result=$(tar -xzf "${restorefrom}" -C "${restoreto}")
  tar_status=$?
  if [ ${tar_status} != 0 ] ; then
    echo -e "${RED}Failed to restore!${NC} status: ${tar_status} result: ${tar_result}"
  else
    echo -e "${GREEN}Restored!${NC}"
  fi
}

level_name_get(){
  local level=$(cat server.properties | grep -E '(level-name=)(.+)' | awk -F'[=]' '{print $2;}')
  echo "${level}"
}

level_name_set(){
  local name_new="$1"
  local name_old="$(level_name_get)"
  sed -i -r "s/${name_old}/${name_new}/g" server.properties
}

# -----------------
# Check environment
# -----------------

if [ -z "${SPIGOT_HOME}" ] ; then
  echo -e "Missing environment variable - ${RED}SPIGOT_HOME${NC} is not set" >$2
  exit 1
fi

if [ -z "${SPIGOT_LEVELDATA}" ] ; then
  echo -e "Missing environment variable - ${RED}SPIGOT_LEVELDATA${NC} is not set" >$2
  exit 1
fi

# ----------------------------------------------------
# LEVELDATA handling
# ----------------------------------------------------
#   Leveldata should be served from a dedicated volume
# ----------------------------------------------------

if [ -n "$1" ]; then  
  if [ -n "$2" -a "$1" = "start" -a "$2" != "$(level_name_get)" ] ; then  
    echo -e "setting levelname: ${YELLOW}$2${NC}"  
    level_name_set $2    
  fi
fi

levelname="$(level_name_get)"
echo -e "level is: ${YELLOW}${levelname}${NC}"
levellink="${SPIGOT_HOME}/${levelname}"
echo "level link is: ${levellink}"
leveldata="${SPIGOT_LEVELDATA}/${levelname}"
echo "level data is stored in: ${leveldata}"

# ------------------
# BACKUP and RESTORE
# ------------------

if [ -n "$1" ]; then
  echo -e "action requested is: ${YELLOW}$1${NC}"
  if [ -n "$2" -a "$1" = "backup" ] ; then    
    echo "doing backup - using parameter: $2"
    level_data_backup $2
    exit 0
  elif [ -n "$2" -a "$1" = "restore" ] ; then
    echo "doing restore using parameter: $2"
    level_data_restore $2 "${SPIGOT_LEVELDATA}/"
    exit 0
  fi
fi

if [ -L ${levellink} ] ; then
  if [ -e ${levellink} ] ; then
    echo "Good level link"
    ls -l ${levellink}
  else
    echo -e "Broken level link ${RED}${levellink}${NC} - is removed"
    level_rmlink ${levellink}
    exit 1
  fi
elif [ -e ${levellink} ] ; then
  echo "Not a link"
  if [ -e ${SPIGOT_LEVELDATA} ] ; then
    echo "Leveldata is mounted"
    if [ ! -e ${leveldata} ] ; then
      echo "moving and linking ${levelname} to ${leveldata}"
      level_data_mv "${levellink}" "${leveldata}"
      level_data_ln "${leveldata}" "${levellink}"
    else
      echo "Level exists local and in leveldata - local data is removed"
      level_data_rm "${levellink}"
      level_data_ln "${leveldata}" "${levellink}"
    fi
  fi
else
  echo "Missing level link"
  if [ -e ${leveldata} ] ; then
    echo "leveldata is mounted - level available"
    level_data_ln "${leveldata}" "${levellink}"
  fi
fi

# ------------
# RUN the game
# ------------

if [ "$1" = "start" ] ; then
  spigot_run
else
  container_sleep
fi