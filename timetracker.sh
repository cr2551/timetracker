#!/bin/bash

#Track the time spent on projects
# set auto tracking: when a command is execute ex: vim .vimrc start session "vimrc" which will track how much time you spend tweaking your .vimrc


PROGDIR=~/.TimeTracker
# create directory if it does not exist
[[ ! -d  "$PROGDIR" ]] && mkdir "$PROGDIR";
session=$(find "$PROGDIR"/ -regex ".*session.*")


# this one is wrong
if [[ "$1" == "--check" ]]; then
    session=$(ls $PROGDIR | grep "session-*")
    if [[ -f "$PROGDIR"/"$session" ]]; then
        echo "session running: $session  $(date "+%M:%S")"
        exit
    else
        echo $(date "+%H:%M %p  %B ")
        exit
    fi
fi



show_time() {
    arr=($( cat "$PROGDIR"/"$project" ))
    total=0
    for i in ${arr[@]}; do
        let total+=$i
    done
    hours="$(( $total / 3600 ))"
    mins="$(( ($total / 60) - ($hours * 60) ))"
    secs="$(( ($total) - (($total / 60) * 60 ) ))"
    echo "Total time recorded for project $project: "
    echo  -e "$hours hours $mins mins $secs seconds \n"
}


close_sess() {
    session=$(find "$PROGDIR"/ -regex ".*session.*")

    total_time=$(( $(date +%s) - $(cat "$session") ))
    project=$( ls "$PROGDIR"/ | grep  -o "session-.*" | awk -F - '{print $(NF)}')
    echo $total_time >> "$PROGDIR"/"$project"
    rm "$PROGDIR"/session-* 
}

start_sess() {
    date +%s >> "$PROGDIR"/session-"$project"
}    





# s option: start session
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
        start_sess && echo "Started session for $project"
        exit
    else
        echo "A Session is already running"
        exit
    fi

# c option: close session    
# this option does not need an argument passed to it. It will look for the file that has the word session in it.
elif [[ "$1" == "-c" ]]; then
    session=$(find "$PROGDIR"/ -regex ".*session.*")
# if there are more than 2 files that match the regex, then the next check will fail
    if [[ -f "$session" ]]; then
        close_sess
        echo "-c $project" >> "$PROGDIR"/.last
        echo "session  $project  closed"
        show_time
        exit
    else
        echo -e "Failed to close session. Session needs to be started first \n "
        exit
    fi

#delete time    
#elif [[ "$1" == "-d" ]]; then
#    amount="$2"
#    project="$3"
#    if [ "$amount" =~ "\d" ] && [ -z "$project" ]; then
#        show_time 
#        echo $(( $total - $amount)) >> $project" 
#    fi
    

#remove last session
elif [[ "$1" == "-r" ]]; then
    session=$(find "$PROGDIR"/ -regex ".*session.*")
# if there are more than 2 files that match the regex, then the next check will fail
    if [[ -f "$session" ]]; then
        rm $session
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
    project=$PROGDIR/$2
    head -n-1 $project > $project

# option p:  pause or resume session    
# does not yet support projects with spaces. 
elif [[ "$1" == "-p" ]]; then

    session=$(find "$PROGDIR"/ -regex ".*session.*")
    
    if [[ -f $session ]]; then
        close_sess
        echo "session  $project  paused"
        echo "-p $project" >> "$PROGDIR"/.last
        exit
    else
        LastLine=$(tail -n 1 "$PROGDIR"/.last)

        if [[ "$LastLine" =~ ^-p ]]; then
            project=$( echo "$LastLine" | awk '{print $2}' )
            start_sess && echo "Resumed Session for $project"
            show_time
        else
            echo "no session to resume"
        fi
        exit
    fi


elif [[ "$1" = "-h" ||  "$1" = "--help"  || "$#" = 0 ]]; then

    echo -e "TimeTracker is a time management utility to record the time spent on user-defined tasks/projects \n"
    echo -e "usage:"
    echo -e "${BOLD}timetracker        [-s PROJECT | -p | -c | -i PROJECT | -h | --help ]${RESET}"
    echo -e "\n    ${BOLD}-s${RESET} PROJECT     Start session for PROJECT"
    echo -e "\n    ${BOLD}-p${RESET}             Pause/resume session"
    echo -e "\n    ${BOLD}-c${RESET}             Close background session for opened project"
    echo -e "\n    ${BOLD}-i PROJECT${RESET}     Display info about the time spent in PROJECT"
    echo -e "\n    ${BOLD}-h, --help${RESET}     Show this message"
    exit
fi

# i option ->  show info about the amount of time recorded into project
if [[ "$1" = "-i" ]]; then
    project="$2"
    show_time
    exit
fi



start_time="$(date  +%s)"
echo -e "\n Tracking time spent on:  $project"
echo -e " Started at            " $(date "+%H:%M %p") "\n"
