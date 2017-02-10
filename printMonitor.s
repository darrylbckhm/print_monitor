#!/usr/bin/bash
#Author: Darryl Beckham
#This script begins at the call to "run" and executes lpstat to determine whether there are print jobs which have been in queue for >2 hours
#This script produces the output file: "./cups_queue.txt"

getCurQueue()
{

  #Removes old cups_queue.txt
  rm -f /var/local/cups_queue.txt

  #Calls lpstat and writes columns containing job #, time sent, AM/PM, and username to "/var/local/cups_queue.txt"
  lpstat -o csif | awk '{print $1, $8, $9, $2, $5}' > /var/local/cups_queue.txt

  #Checks if any print job info is in file
  if [ ! -s /var/local/cups_queue.txt ]; then

    printf "Queue is empty!\n"
    exit

  fi 

  #Uses sed to remove printer name from string of the form "printer_name-job_number"
  #Uses sed to substitute all colons for spaces to simplify operations using the timestamp provided by lpstat
  sed -i.bak -e 's/.*-//' -e 's/:/ /g' /var/local/cups_queue.txt

}

#Parses cups_queue.txt and removes jobs older than 2 hours from print queue
removeOldJobs()
{

  #Reads each line in cups_queue.txt and assigns each section of text to a corresponding variable a, b. c, d, e, f, g (space delimited)
  while read -r a b c d e f g; do

    #Local variables used to determine job number, time in queue, AM/PM, username, job date, and current date
    job_num=$a
    job_hour=$b
    job_min=$c
    am_pm=$e #Time is initially stored in 12-hour time format
    user=$f
    job_date=$g
    cur_date=`date +%d`
    cur_min=`date +%M`

    #Check if job is over 24 hours old
    #If so, remove it and continue to next job in queue
    if [ $job_date -ne $cur_date ] && [ $am_pm == "AM" ] && [ $job_hour -ge 2 ]; then

      lprm $job_num
      exit

    fi


    #Begin conversion from 12-hour to 24-hour time format
    if [ $am_pm == "AM" ] && [ $job_hour -eq 12 ]; then

      job_hour=0

    fi

    if [ $am_pm == "PM" ] && [ $job_hour -ne 12 ]; then

      let job_hour+=12

    fi
    #End conversion from 12-hour to 24-hour time format


    #Calculate the number of hours the job has been in the queue by subtracting the current hour from the hour given by lpstat
    let hours_passed=`date +%H`-$job_hour

    #If more than 2 hours have passed, remove the job specified by job_num
    if [ $hours_passed -gt 2 ]; then

      printf "Job #$job_num: $user sent this job at least 2 hours ago and will now be removed from the print queue.\n"
      lprm $job_num
      continue

    fi

    #If at least 2 hours has passed, remove the job specified by job_num
    if [ $hours_passed -eq 2 ] && [ cur_min -ge job_min ]; then

      printf "Job #$job_num: $user sent this job at least 2 hours ago and will now be removed from the print queue.\n"
      lprm $job_num
      continue
    fi

    #If the job has been in the queue for less than 2 hours, do nothing
    printf "Job #$job_num: $user sent this job less than 2 hours ago and it is currently ineligible for removal.\n"

  #Input file to read
  done </var/local/cups_queue.txt

}

run()
{

  #Writes relevant information from lpstat to "/var/local/cups_queue.txt"
  getCurQueue

  #Removes outdated print jobs from print queues
  removeOldJobs

  exit

}

run
