#! /usr/bin/bash

## additional scripts to read eiscat hdf5 files data outside of guisdap to matlab and python
if ! [ -d "./user_scripts" ]; then \
    cp -r /opt/guisdap/user_scripts .
    fix-permissions "/home/${NB_USER}/user_scripts"; else \
    rsync -abviuz /opt/guisdap/user_scripts/ /home/${NB_USER}/user_scripts
    fix-permissions "/home/${NB_USER}/user_scripts"
fi

## if not existing create folders necessary for guisdap
for i in "./gup" "./gup/mygup" "./results" "./mydata" "./tmp" 
do
    if ! [ -d $i ]; then \
        mkdir $i
        fix-permissions "/home/${NB_USER}/$i"
    fi
done

# if we are on eiscat server and licence is used link shared folder
if [ "$MLM_LICENSE_FILE" = "27000@hqserv" ]; then \
    if ! [ -d "./shared_data" ]; then \
         ln -s /shared_data /home/$NB_USER; \
    fi 
fi

if ! [ -f .wgetrc ]; then \
    echo "content-disposition = on" >> /home/${NB_USER}/.wgetrc
fi

