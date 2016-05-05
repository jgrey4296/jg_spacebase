## SpaceBase DF-9 Install Makefile (OSX)
# Author: John Grey Wed May 04 23:48:05 PDT 2016
#

INSTALLDIR = ~/SpaceBase/Space.app/Contents/MacOS/
FOCUSDIR = Data


all : install

backup :
ifeq (${wildcard ${INSTALLDIR}/${FOCUSDIR}.zip},"")
	@echo "Backup Doesnt Exist, creating"
	zip -r ${INSTALLDIR}/${FOCUSDIR}.zip ${INSTALLDIR}/${FOCUSDIR};
endif

#install the zip into the mods directory
install : backup 
	rsync -I -avz ${FOCUSDIR}/ ${INSTALLDIR}/${FOCUSDIR}
