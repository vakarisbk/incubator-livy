#!/usr/bin/env bash

# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Runs Livy server.


usage="Usage: livy-server (start|stop|status)"

#export LIVY_HOME=$(cd $(dirname $0)/.. && pwd)
LIVY_CONF_DIR=${LIVY_CONF_DIR:-"$LIVY_HOME/conf"}

if [ -f "${LIVY_CONF_DIR}/livy-env.sh" ]; then
  # Promote all variable declarations to environment (exported) variables
  set -a
  . "${LIVY_CONF_DIR}/livy-env.sh"
  set +a
fi

# Find the java binary
if [ -n "${JAVA_HOME}" ]; then
  RUNNER="${JAVA_HOME}/bin/java"
elif [ `command -v java` ]; then
  RUNNER="java"
else
  echo "JAVA_HOME is not set" >&2
  exit 1
fi

LIVY_IDENT_STRING=${LIVY_IDENT_STRING:-"$USER"}
LIVY_PID_DIR=${LIVY_PID_DIR:-"/tmp"}
LIVY_MAX_LOG_FILES=${LIVY_MAX_LOG_FILES:-5}
pid="$LIVY_PID_DIR/livy-$LIVY_IDENT_STRING-server.pid"

livy_rotate_log() {
  log=$1
  num=$LIVY_MAX_LOG_FILES

  if [ $LIVY_MAX_LOG_FILES -lt 1 ]; then
    num=5
  fi

  if [ -f "$log" ]; then # rotate logs
	while [ $num -gt 1 ]; do
	  prev=`expr $num - 1`
	  [ -f "$log.$prev" ] && mv "$log.$prev" "$log.$num"
	  num=$prev
	done
    mv "$log" "$log.$num"
  fi
}

create_dir() {
  dir_name=$1
  dir_variable=$2
  if [ ! -d "$dir_name" ]; then
    mkdir -p $dir_name
  fi
  if [ ! -w "$dir_name" ]; then
    echo "$USER doesn't have permission to write to directory $dir_name (defined by $dir_variable)."
    exit 1
  fi
}

start_livy_server() {
  LIBDIR="$LIVY_HOME/jars"
  if [ ! -d "$LIBDIR" ]; then
    LIBDIR="$LIVY_HOME/server/target/jars"
    THRIFT_LIBDIR="$LIVY_HOME/thriftserver/server/target/jars"
  fi
  if [ ! -d "$LIBDIR" ]; then
    echo "Could not find Livy jars directory." 1>&2
    exit 1
  else
    if [ -d "$THRIFT_LIBDIR" ]; then
      LIBDIR="$THRIFT_LIBDIR/*:$LIBDIR"
    fi
  fi

  LIVY_CLASSPATH="${LIVY_CLASSPATH:-${LIBDIR}/*:${LIVY_CONF_DIR}}"

  if [ -n "$SPARK_CONF_DIR" ]; then
    LIVY_CLASSPATH="$LIVY_CLASSPATH:$SPARK_CONF_DIR"
  fi
  if [ -n "$HADOOP_CONF_DIR" ]; then
    LIVY_CLASSPATH="$LIVY_CLASSPATH:$HADOOP_CONF_DIR"
  fi
  if [ -n "$YARN_CONF_DIR" ]; then
    LIVY_CLASSPATH="$LIVY_CLASSPATH:$YARN_CONF_DIR"
  fi

  command="$RUNNER $LIVY_SERVER_JAVA_OPTS -cp $LIVY_CLASSPATH:$CLASSPATH org.apache.livy.server.LivyServer"

  if [ $1 = "old" ]; then
    exec $command
  else
    # get log directory
    LIVY_LOG_DIR=${LIVY_LOG_DIR:-${LIVY_HOME}/logs}
    create_dir $LIVY_LOG_DIR "LIVY_LOG_DIR"
    create_dir $LIVY_PID_DIR "LIVY_PID_DIR"
    log="$LIVY_LOG_DIR/livy-$LIVY_IDENT_STRING-server.out"
    # Set default scheduling priority
    LIVY_NICENESS=${LIVY_NICENESS:-0}
    if [ -f "$pid" ]; then
      TARGET_ID="$(cat "$pid")"
      if [[ $(ps -p "$TARGET_ID" -o comm=) =~ "java" ]]; then
        echo "livy-server running as process $TARGET_ID.  Stop it first."
        exit 1
      fi
    fi

    livy_rotate_log "$log"
    echo "starting $command, logging to $log"
    nohup nice -n "$LIVY_NICENESS" $command >> "$log" 2>&1 < /dev/null &
    newpid="$!"
    echo "$newpid" > "$pid"
    sleep 2
    # Check if the process has died; in that case we'll tail the log so the user can see
    if [[ ! $(ps -p "$newpid" -o comm=) =~ "java" ]]; then
      echo "failed to launch $command:"
      tail -2 "$log" | sed 's/^/  /'
      echo "full log in $log"
      rm -rf "$pid"
      exit 1
    fi
  fi
}

option=$1

case $option in

  (start)
    start_livy_server "new"
    ;;

  ("")
    # make it compatible with previous version of livy-server
    start_livy_server "old"
    ;;

  (stop)
    if [ -f "$pid" ]; then
      TARGET_ID="$(cat "$pid")"
      if [[ $(ps -p "$TARGET_ID" -o comm=) =~ "java" ]]; then
        echo "stopping livy-server"
        kill "$TARGET_ID" && rm -f "$pid"
      else
        echo "no livy-server to stop"
      fi
    else
      echo "no livy-server to stop"
    fi
    ;;

  (status)
    if [ -f "$pid" ]; then
      TARGET_ID="$(cat "$pid")"
      if [[ $(ps -p "$TARGET_ID" -o comm=) =~ "java" ]]; then
        echo "livy-server is running (pid: $TARGET_ID)"
      else
        echo "livy-server is not running"
      fi
    else
      echo "livy-server is not running"
    fi
    ;;

  (*)
    echo $usage
    exit 1
    ;;

esac

#java -cp "/opt/livy/jars/*" org.apache.livy.server.LivyServer
