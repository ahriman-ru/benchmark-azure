#!/bin/sh
# Storage for downloaded files and IO / tests
# Typically $HOME (/root/benchmark) is a good place.
# You need approximately 10 GB of free space.
MY_DIR=${share_azure}
declare -r share_azure="/mnt/share"
declare -r hst=$(hostname)
MY_OUTPUT="${share_azure}/${hst}.html"


function hostname_fqdn() {
  echo_step "Hostname (FQDN)"
  if hostname -f &>/dev/null; then
    hostname -f >> "$MY_OUTPUT"
  elif hostname &>/dev/null; then
    hostname >> "$MY_OUTPUT"
  else
    echo "Hostname could not be determined"
  fi
}


prepare(){
  sudo yum install -y samba-client samba-common cifs-utils nfs-utils lib    
}

connect_to_azure_files_share(){
  declare -r shareazure_path="//benchmarksresults.file.core.windows.net/results"
  declare -r share_pass="nBPTOwpONvXwfgXr7dwG1jElnlBEakV9w6nSW53TSMHDp9Gd1kGtxfzKQ1jihXSk7dDeUCERIup+dSX06NaLGw=="
  declare -r share_username="benchmarksresults"

  declare share_include_cmd="${shareazure_path} ${share_azure} -o vers=3.0,username=${share_username},password=${share_pass},dir_mode=0777,file_mode=0777,serverino"
  mkdir -p ${share_azure}
  mount -t cifs ${share_include_cmd}
  echo ${share_include_cmd} >> /etc/fstab
}



GEEKBENCH_DOWNLOAD_URL="http://cdn.primatelabs.com/Geekbench-4.0.3-Linux.tar.gz"
UNIXBENCH_DOWNLOAD_URL="https://github.com/kdlucas/byte-unixbench/archive/v5.1.3.tar.gz"

function echo_title() {
  echo "> $1"
  echo "<h1>$1</h1>" >> "$MY_OUTPUT"
}

# echo_step() outputs a step to stdout and MY_OUTPUT
function echo_step() {
  echo "    > $1"
  echo "<h2>$1</h2>" >> "$MY_OUTPUT"
}

# echo_sub_step() outputs a step to stdout and MY_OUTPUT
function echo_sub_step() {
  echo "      > $1"
  echo "<h3>$1</h3>" >> "$MY_OUTPUT"
}

# echo_code() outputs <pre> or </pre> to MY_OUTPUT
function echo_code() {
  case "$1" in
    start)
      echo "<pre>" >> "$MY_OUTPUT"
      ;;
    end)
      echo "</pre>" >> "$MY_OUTPUT"
      ;;
  esac
}

# echo_equals() outputs a line with =
function echo_equals() {
  COUNTER=0
  while [  $COUNTER -lt "$1" ]; do
    printf '='
    let COUNTER=COUNTER+1 
  done
}

# echo_line() outputs a line with 70 =
function echo_line() {
  echo_equals "70"
  echo
}

# exit_with_failure() outputs a message before exiting the script.
function exit_with_failure() {
  echo
  echo "FAILURE: $1"
  echo
  exit 9
}

function check_operating_system() {
  MY_UNAME_S="$(uname -s 2>/dev/null)"
  if [ "$MY_UNAME_S" = "Linux" ]; then
    echo "    > Operating System: Linux"
  else
    exit_with_failure "Unsupported operating system 'MY_UNAME_S'. Please use 'Linux' or edit this script :-)"
  fi
}


function cpu_info() {
  echo_step "CPU Info"
  if [[ -f "/proc/cpuinfo" ]]; then
    MY_CPU_COUNT=$(grep -c processor /proc/cpuinfo)
    echo_code start
    cat "/proc/cpuinfo" >> "$MY_OUTPUT"
    echo_code end
  else
    exit_with_failure "'/proc/cpuinfo' does not exist"
  fi
}

function mem_info() {
  echo_step "RAM Info"
  if [[ -f "/proc/meminfo" ]]; then
    echo_code start
    cat "/proc/meminfo" >> "$MY_OUTPUT"
    echo_code end
  else
    exit_with_failure "'/proc/meminfo' does not exist"
  fi
  
  echo_step "Free"
  echo_code start
  free -m >> "$MY_OUTPUT"
  echo_code end
}

if [[ ! -d "$MY_DIR" ]]; then
  mkdir "$MY_DIR" || exit_with_failure "Could not create folder '$MY_DIR'"
fi

echo "    > Download UnixBench"
if curl -fsL "$UNIXBENCH_DOWNLOAD_URL" -o "/tmp/unixbench.tar.gz"; then
  if tar xvfz "/tmp/unixbench.tar.gz" -C "/tmp/" --strip-components=1 > /dev/null 2>&1; then
    cd "/tmp/UnixBench" || exit_with_failure "Could not find folder '/tmp/UnixBench'"
    if make > /dev/null 2>&1; then
      echo "        > UnixBench successfully downloaded and compiled"
    else
      exit_with_failure "Could not build (make) UnixBench"
    fi
  else
    exit_with_failure "Could not unpack '/tmp/unixbench.tar.gz'"
  fi
else
  exit_with_failure "Could not download UnixBench '$UNIXBENCH_DOWNLOAD_URL'"
fi

# Download Geekbench 4
echo "    > Download Geekbench 4"
if curl -fsL "$GEEKBENCH_DOWNLOAD_URL" -o "/tmp/geekbench.tar.gz"; then
  if tar xvfz "/tmp/geekbench.tar.gz" -C "/tmp/" --strip-components=3 > /dev/null 2>&1; then
    if [[ -x "/tmp/geekbench4" ]]; then
      echo "        > Geekbench successfully downloaded"
    else
      exit_with_failure "Could not find '/tmp/geekbench4'"
    fi
  else
    exit_with_failure "Could not unpack '$MY_DIR/geekbench.tar.gz'"
  fi
else
  exit_with_failure "Could not download Geekbench '$GEEKBENCH_DOWNLOAD_URL'"
fi

prepare
connect_to_azure_files_share

#echo_step date
#echo_step whoami

echo_title "System Info"

# Location for the HTML benchmark results
# This can also be $MY_DIR (/root/benchmark/output.html)


echo_step "Kernel"; uname -a >> "$MY_OUTPUT"

echo_step "Date and Time"; echo "$MY_DATE_TIME" >> "$MY_OUTPUT"

echo_step "Hardware Lister (lshw)"
echo_code start
lshw >> "$MY_OUTPUT"
echo_code end

cpu_info

mem_info

#network_info

echo_line
echo " Now let's run the good old UnixBench. This takes a while."
echo "      Time to get a Club Mate..."
echo_line
echo_title "UnixBench"
echo_code start
perl "/tmp/UnixBench/Run" -c "1" -c "$MY_CPU_COUNT" >> "$MY_OUTPUT" 2>&1
echo_code end

echo_line
echo "Now let's run the new and hip Geekbench 4. This takes a little longer."
echo_line

echo_title "Geekbench 4"
echo_code start
"/tmp/geekbench4" | grep "browser.geekbench.com" | head -n 1 >> "$MY_OUTPUT" 2>&1
echo_code end

{
  echo "<hr>"
  echo "$ME - $MY_DATE_TIME"
  echo "</html>"
} >> "$MY_OUTPUT"

echo
echo_line
echo
echo " D O N E"
echo
echo " HTML file for analysis:"
echo "      $MY_OUTPUT"
echo
echo_line
echo
exit 0

