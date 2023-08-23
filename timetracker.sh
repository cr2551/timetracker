#!/bin/bash

# var to store program related things like a stopwatch file and whether or not a session is running
PROGDIR=~/.TimeTracker
# subpath to store the names of the actual projects and their time
PROJECTSDIR=~/.TimeTracker/projects
# create directory if it does not exist
[[ ! -d  "$PROGDIR" ]] && mkdir "$PROGDIR";
[[ ! -d  "$PROJECTSDIR" ]] && mkdir "$PROJECTSDIR";
# find an open session if it exists, otherwise returns nothing
session=$(find "$PROGDIR"/ -regex ".*session.*")




start_stopwatch() {

    seconds=0
    minutes=0
    hours=0
    while true; do
        sleep 1
        # this is preferable to expr since it avoids fork/execute for the expr command
        seconds=$(( seconds + 1 ))
        if [ "$seconds" = 60 ]; then
            minutes=$(( minutes + 1 ))
            seconds=0
        fi
        if [ "$minutes" = 60 ]; then
            hours=$(( hours + 1 ))
            minutes=0
        fi
    # write to a file that we will read from
        echo  "$hours h : $minutes m : $seconds s" > ~/.TimeTracker/stopwatch
        #echo "$hours h : $minutes m : $seconds s"

    done
}

show_time() {
    arr=($( cat "$PROJECTSDIR"/"$project" ))
    total=0
    for i in "${arr[@]}"; do
        (( total+=i ))
    done
    hours="$(( total / 3600 ))"
    mins="$(( (total / 60) - (hours * 60) ))"
    secs="$(( (total) - ((total / 60) * 60 ) ))"
    echo "Total time recorded for project $project: "
    echo  -e "$hours hours $mins mins $secs seconds \n"
}


close_sess() {

    # find and remove file that  start with session.
    session=$(find "$PROGDIR"/ -regex ".*session.*")
    project=$( ls "$PROGDIR"/ | grep  -o "session-.*" | awk -F - '{print $(NF)}')
    session_seconds=$(( $(date +%s) - $(cat "$session") ))
    rm "$PROGDIR"/session-*

    # append seconds to project file
    echo $session_seconds >> "$PROJECTSDIR"/"$project"

    # print time spent in the last session
    formatted_seconds=$(( $session_seconds % 60 ))
    minutes=$(( $session_seconds / 60 ))
    hours=$(( $session_seconds / 3600 ))
    echo "time spent in session: $hours hours $minutes mins and $formatted_seconds seconds"

}

start_sess() {
    # put seconds since epoch in this file, when we close the session we will subtract the seconds at the time of closing from the value stored
    # in this file
    date +%s >> "$PROGDIR"/session-"$project"

    echo -e "\n Tracking time spent on:  $project"
    echo -e " Started at            \"$(date "+%H:%M %p")\"\n"
}


# function to kill stopwatch timer
kill_watch() {
    #overwrite the file with an empty string
    echo "" > "$PROGDIR/stopwatch"
}



# -s option: start session
# takes the argument project and calls the start_sess func which
# creates a file that starts with the word "session"
if [ "$1" == "-s" ]; then
    # checks if there is a session already running
    # it will exit if there is, even if it is not the same.
    if [[ ! -f "$session" ]]; then
        shift 1
        # the "$*" will allow the user to enter a project name with spaces
        project="$*"
        if [ "$project" == "" ]; then
            echo "provide a project name"
            exit
        fi
        start_sess
        # redirecting the output to /dev/null is essential, even
        #though the output was already going to the stopwatch file in PROJECTSDIR
        #nohup stopwatch.sh > "$PROJECTSDIR"/stopwatch >&1 &
        #stopwatch.sh > /dev/null >&1 &
        start_stopwatch > /dev/null >&1 &
        echo $! | tee $PROGDIR/child_process_id

        exit

    else
        echo "A Session is already running"
        exit
    fi



# -c option: close session
# this option does not need an argument passed to it. It will look for the file that has the word session in it.
elif [[ "$1" == "-c" ]]; then

    #kill $(ps -e | grep "stopwatch.sh" | awk {'print $1'})
    session=$(find "$PROGDIR"/ -regex ".*session.*")
# if there are more than 2 files that match the regex, then the next check will fail
    if [[ -f "$session" ]]; then
        #kill timetracker process that never stopped running
        kill "$(cat $PROGDIR/child_process_id)"
        kill_watch
        close_sess
        echo "-c $project" >> "$PROGDIR"/.last
        echo "session  $project  closed"
        show_time
        exit
    else
        echo -e "Failed to close session. Session needs to be started first \n "
        exit
    fi


#delete last saved session needs more work
elif [[ "$1" == "-d" ]]; then
    LastLine=$(tail -n 1 "$PROGDIR"/.last)
            # use awk to get all but the first field
    project_name=$( echo "$LastLine" | awk '{for (i=2; i<=NF; i++) {printf "%s", $i; if(i<NF) printf " "}; printf ""}' )
    project_path=$PROJECTSDIR/$project_name
    head -n-1 "$project_path" > "$PROGDIR"/tmp
    cat "$PROGDIR"/tmp > "$project_path" && echo deleted last session of "$project_name"
    rm "$PROGDIR"/tmp


# option p:  pause or resume session
elif [[ "$1" == "-p" ]]; then

    session=$(find "$PROGDIR"/ -regex ".*session.*")
    if [[ -f "$session" ]]; then
        close_sess
        echo "session  $project  paused"
        # saves just the name of the project not the whole file path
        echo "-p $project" >> "$PROGDIR"/.last
        # send SIGSTOP signal (19) to stopwatch
        # pressing ctrl z on the terminal sends a SIGTSTP (20)
        kill -19 "$(cat "$PROGDIR"/child_process_id)"
        # but don't overwrite the stopwatch file
        exit

    else
        LastLine=$(tail -n 1 "$PROGDIR"/.last)
        if [[ "$LastLine" =~ ^-p ]]; then
            # use awk to get all but the first field wich contains "-p"
            project=$( echo "$LastLine" | awk '{for (i=2; i<=NF; i++) {printf "%s", $i; if(i<NF) printf " "}; printf ""}' )
            #or we could use pcregrep:
            # pcregrep -o "(?<=-p)\s.*"
            start_sess && echo "Resumed Session for $project"
            # restart the process so the stopwach child process can start running again.
            kill -CONT "$(cat "$PROGDIR"/child_process_id)"
            show_time
        else
            echo "no session to resume"
        fi
        exit
    fi

# -i option ->  show info about the amount of time recorded into project
elif [[ "$1" = "-i" ]]; then
    project="$2"
    show_time
    exit

elif [[ "$1" = "-h" ||  "$1" = "--help"  || "$#" = 0 ]]; then

    echo -e "TimeTracker is a time management utility to record the time spent on user-defined tasks/projects \n"
    echo -e "usage:"
    echo -e "${BOLD}timetracker        [-s PROJECT | -p | -c | -i PROJECT | -h | --help ]${RESET}"
    echo -e "\n    ${BOLD}-s${RESET} PROJECT     Start session for PROJECT"
    echo -e "\n    ${BOLD}-p${RESET}             Pause/resume session"
    echo -e "\n    ${BOLD}-c${RESET}             Close background session for opened project"
    echo -e "\n    ${BOLD}-d${RESET}             Delete last saved session"
    echo -e "\n    ${BOLD}-i PROJECT${RESET}     Display info about the time spent in PROJECT"
    echo -e "\n    ${BOLD}-h, --help${RESET}     Show this message"
    exit
fi

