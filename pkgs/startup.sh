#! /usr/bin/bash

## additional scripts to read eiscat hdf5 files data outside of guisdap to matlab and python
if ! [ -d "./user_scripts" ]; then \
    cp -r /opt/guisdap/user_scripts .
fi

## if not existing create folders necessary for guisdap
for i in "./gup" "./gup/mygup" "./results" "./mydata" "./tmp" 
do
    if ! [ -d $i ]; then \
        mkdir $i
    fi
done

# # if we are on eiscat server and licence is used link shared folder
# if [ "$MLM_LICENSE_FILE" = "27000@hqserv" ]; then \
#     ln -s /shared_data /home/$NB_USER; \
# fi

## do we need to check somehow changes in the home folder? (what if we add something to the home folder?)
# diff -r(?)
