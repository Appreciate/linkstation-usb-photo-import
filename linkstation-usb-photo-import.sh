#!/bin/sh
CAMERA="4a9/313a/2"
TMPDIR=/mnt/disk1/tmp/canon
LOGFILE=/var/log/hotplug.log
ERRORLOG=$TMPDIR/error.log
BASEDIR=/mnt/disk1/myphotos/

# user and group that'll own the images
IMGUSR=guest
IMGGRP=hdusers


error()
# write error message into ERRORLOG, let error/diag led blink
{
    echo $1 >> $ERRORLOG

    # play signal tones
    miconapl -a bz_melody 300 a4 g4

    # blink error LED
    miconapl -a led_set_cpu_mcon diag on
    miconapl -a led_set_on_off diag on
    miconapl -a led_set_brink diag on
}

get_images()
# copy images from camera and delete them there,
# during operation info LED flashes
{
    # turn info LED on and let it blink while copying from camera
    miconapl -a led_set_on_off info
    miconapl -a led_set_brink info

    # copy photos into current dir using gphoto2
    gphoto2 -P || error "Error in gphoto2 -RP, code: $?" >> $ERRORLOG

    # if everything works, uncomment next line to delete images from the camera
    # gphoto2 -RD || error "Error in gphoto2 -RD, code: $?" >> $ERRORLOG

    # turn info LED off again and clear blink status
    miconapl -a led_set_on_off info off
    miconapl -a led_set_brink info off
}

process_photos()
# automatic processing of  photo files
{
    # autorotate images according to the exif-flags
    # also set modification time to exif-date/time
    # exit codes of jhead: 0=OK, 1=Modified
    /opt/bin/jhead -autorot -ft *.JPG >> $ERRORLOG

    # jhead returns "1" in case of successful modification (e.g. rotation)
    if [ "$?" -lt "0"]; then
       error "Error in jhead operation, code: $?"
    fi
}

copy_images()
# move all images into photo folders
{
    chown $IMGUSR:$IMGGRP *.JPG *.AVI
    chmod a+rw,a-x *.JPG *.AVI

    for photo in *.JPG *.AVI; do
      if [ ! -f "$photo" ]; then
        # continue with next loop if it's not a file
        continue
      fi

      # get the year and month of the photo - separate vars if further processing is desired
      date_year=`date -r "$photo" +"%Y"` || echo "error in date_year with $photo, code $?"
      date_month=`date -r "$photo" +"%m"`|| echo "error in date_month with $photo, code $?"

      # compose target folder for the photo
      year_dir="$BASEDIR/$date_year""_Fotos"
      photo_dir="$year_dir/$date_year$date_month"

      # make sure the target folder exists and has proper permissions set
      if [ ! -e $year_dir ]; then
          mkdir "$year_dir"
          chown $IMGUSR:$IMGGRP "$year_dir"
          chmod a+rwx "$year_dir"
      fi

      if [ ! -e $photo_dir ]; then
          mkdir "$photo_dir"
          chown $IMGUSR:$IMGGRP "$photo_dir"
          chmod a+rwx "$photo_dir"
      fi

      # cp the file, if everything works change to move (mv)
      cp "$photo" "$photo_dir/$photo" || echo "error copying $photo, code $?"

    done
}


#
# main program follows
#

# enable the line below to get the product ID written out (debugging or new device))
#
# echo "canon.hotplug: $ACTION $PRODUCT" >> /var/log/hotplug.log

if [ "$PRODUCT" == "$CAMERA" ]; then

  echo "`date`: Found the Canon to $ACTION!" >> $LOGFILE

  if [ "$ACTION" == "add" ]; then
    PATH=$PATH:/opt/bin:/usr/local/bin:/usr/local/sbin
    export PATH

    echo `date` > $ERRORLOG
    # create temporary dir, cd there
    if [ ! -e $TMPDIR ]; then
        mkdir $TMPDIR || error "error creating tempdir $TMPDIR"
    fi
    cd $TMPDIR
    rm *.JPG *.AVI *.JPEG

    # set info led into cpu control mode
    miconapl -a led_set_cpu_mcon info on

    # get images, while accessing camera info LED blinks
    get_images

    # during processing switch info LED on
    miconapl -a led_set_on_off info

    process_photos
    copy_images

    # processing complete, switch info LED off
    miconapl -a led_set_on_off info off

    # switch info led back to mcon control
    miconapl -a led_set_cpu_mcon info off

    # do some housekeeping
    # rm -rf $TMPDIR
    echo "`date`: Image processing for Canon complete." >> $LOGFILE

  fi
fi

exit 0