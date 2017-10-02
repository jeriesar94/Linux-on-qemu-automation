#!/bin/bash
script_path=$(readlink -f -- "$0")
script_directory=${script_path%/*}
#<------General predefined paths for builds----->
BUSY_BOX="busybox-1.26.2"
IOZONE="iozone3_465"
LINUX_KERNEL="linux-4.11"
QEMU="qemu-2.9.0"
OUT="out"
#<------------END OF PATHS---------------------->
function test_qemu {
	echo "Testing QEMU..."
	./out/qemu-out/bin/qemu-system-x86_64 --version > /dev/null
	catch_and_report_error $? -5 "QEMU"
	echo "PASS"
	
}

function test_busybox {
	echo "Testing BusyBox..."
	./out/busybox-x86/busybox whoami > /dev/null
	catch_and_report_error $? -5 "BusyBox"
	echo "PASS"
}

function test_iozone {
	echo "Testing IOZONE..."
	./iozone3_465/src/current/iozone -h > /dev/null
	catch_and_report_error $? -5 "IOZONE"
	echo "PASS"
}

function catch_and_report_error {
	# $1 Represents error code reported by bash shell '$?'
	# $2 Represents error code of script process in action 'Download, extracting, make command,...'
	# $3 Represents a string to be concatenated with the error message to explain in which step the error occurred.
	if [ $1 != 0 ]; then
		case $2 in 
			-1) echo "ERROR: cannot download $3!";;

			-2) echo "ERROR: Problem with extracting archive '$3'.";;

			-3) echo "ERROR: in command '$3'.";;
			
			-4) echo "ERROR: Entered wrong $3";;
			
			-5) echo "$3: FAIL :(";
			    echo "Testing failed...";;

			-6) echo "Failed to install package\s $3";;


			 *) echo "Unknown error occured!";;

		esac

		echo "Exiting..."
		exit $2;
	fi

}

function install_packages {
	#$1 Represents package name
	echo
	echo "$1 not found! package\s "$1" are needed."
	echo "installing package\s..."
	sudo apt-get -qq install "$1" > /dev/null
	catch_and_report_error $? -6 "$1"
	echo "package\s installed."
	echo	
}

function check_packages {
	packages_array=()
	packages_array[0]="libncurses5-dev libncursesw5-dev"
	packages_array[1]="libssl-dev"
	packages_array[2]="libglib2.0-dev"
	packages_array[3]="zlib1g-dev"
	packages_array[4]="autoconf"
	packages_array[5]="dh-autoreconf"
	packages_array[6]="flex"
	packages_array[7]="bison"
	
	#Query the dpkg database for packages in 'packages_array'
	for entry in ${packages_array[@]}; do
		echo "Checking if package\s $entry exist\s"
		dpkg-query -s "$entry" >/dev/null 2> /dev/null
		if [ $? != 0 ]; then
			install_packages $entry
		fi 
	done
}

function download_archives {
	echo -e "\nDownloading Needed archives..."
	#Check if archives exist at the location of the TOP directory, download otherwise.
	if [[ ! -e "busybox-1.26.2.tar.bz2" ]]; then

		echo "Downloading BusyBox..."
		curl -# -f --connect-timeout 80 -m 600 -o busybox-1.26.2.tar.bz2 https://www.busybox.net/downloads/busybox-1.26.2.tar.bz2
		#Catch any errors, notify user and exit script (Same for the statements in other archives below). 
		catch_and_report_error $? -1 "BusyBox"

	fi
	echo -e "-Downloaded BusyBox-\n\n"
	if [[ ! -e "iozone3_465.tar" ]]; then

		echo "Downloading IOZONE..."

		curl -# -f --connect-timeout 80 -m 600 -o iozone3_465.tar http://www.iozone.org/src/current/iozone3_465.tar
		catch_and_report_error $? -1 "IOZONE"

	fi
	echo -e "-Downloaded IOZONE-\n\n"
	if [[ ! -e "linux-4.11.tar.xz" ]]; then

		echo "Downloading Linux Kernel v4.11 ..."

		curl -# -f --connect-timeout 80 -m 600 -o linux-4.11.tar.xz https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-4.11.tar.xz
		catch_and_report_error $? -1 "Kernel"

	fi
	echo -e "-Downloaded Linux Kernel-\n\n"
	if [[ ! -e "qemu-2.9.0.tar.xz" ]]; then
		echo "Downloading QEMU v2.9.0 ..."

		curl -# -f --connect-timeout 80 -m 600 -o qemu-2.9.0.tar.xz https://download.qemu.org/qemu-2.9.0.tar.xz
		catch_and_report_error $? -1 "QEMU"

	fi
	echo -e "-Downloaded QEMU-\n\n"

	echo "Packages downloaded successfully."
}

function extract_archives {
	echo "Extracting archives..."
	echo 
	echo "Extracting 'busybox-1.26.2.tar.bz2'"
	tar xf busybox-1.26.2.tar.bz2
	#Catch any errors during extraction, notify user and exit script (Some for the statements in other archives below). 
	catch_and_report_error $? -2 "busybox-1.26.2.tar.bz2"
	echo "Success."
	echo 
	echo "Extracting 'iozone3_465.tar'"
	tar xf iozone3_465.tar
	catch_and_report_error $? -2 "iozone3_465.tar"
	echo "Success."
	echo 
	echo "Extracting 'linux-4.11.tar.xz'"
	tar xf linux-4.11.tar.xz
	catch_and_report_error $? -2 "linux-4.11.tar.xz"
	echo "Success."
	echo 
	echo "Extracting 'qemu-2.9.0.tar.xz'"
	tar xf qemu-2.9.0.tar.xz
	catch_and_report_error $? -2 "qemu-2.9.0.tar.xz"
	echo "Success."
	echo
	echo -e "Archives Extracted Successfully.\n"
}
#=================BusyBox======================
function build_busybox {
	echo "Building BusyBox..."
	cd $BUSY_BOX
	mkdir -p ../out/busybox-x86

	echo
	echo "A configuration menu will now open,"
	echo
	echo -e "configure options - choose a static binary build and exit while saving the
	'.config' file (the rest of the options can be left with their default settings)\n
	    		-> Busybox Settings\n
				-> Build Options\n
		   			[*] Build BusyBox as a static binary (no shared libs)"
	echo

	make O=../out/busybox-x86 menuconfig -s 2> /dev/null
	catch_and_report_error $? -3 "make menuconfig"

	echo "Building BusyBox binary..."
	make O=../out/busybox-x86 -s > /dev/null 2> /dev/null
	catch_and_report_error $? -3 "make"

	make O=../out/busybox-x86 install -s > /dev/null 2> /dev/null
	catch_and_report_error $? -3 "make install"
	echo "Done."
	echo

	cd ../$OUT
	echo "Creating Directory strucutre, default scripts and set-up files..."
	mkdir -p initramfs-x86
	cd initramfs-x86
	mkdir -p {bin,sbin,etc,proc,sys,usr/{bin,sbin},tmp,mnt/{1,2,3,4},testing}

	echo "Copying BusyBox binary and links..."
	cp -a ../busybox-x86/_install/* .

	echo "Creating the passwords file..."
	echo "root::0:0:root:/root:/bin/sh" > ../initramfs-x86/etc/passwd
	echo

	echo "#!/bin/sh
	mount -t proc none /proc
	mount -t sysfs none /sys
	mount none /sys/kernel/debug/ -t debugfs
	mount none /tmp -t tmpfs
	# populate '/dev/ directory
	mdev -s
	# start shell in an endless loop
	echo -e \"\n\n** miniboot started **\n\"
	while true
		do echo \"Starting a new shell.. (up $(cut -d' ' -f1 /proc/uptime) seconds)\"
		# note - 'ENV=/.shinit' is optional and used for defining various aliases
		# using the user defined '.shinit' script
		ENV=/.shinit /bin/sh -l
	done" > init
	chmod +x ./init

	echo  "# a shortcut to quit the emulation environment cleanly
	alias q='poweroff -f'

	alias ll='ls -alF'
	alias lt='ls -altrF'

	# more user defined aliases can be easily defined here.." > .shinit
}
#=================IOZONE======================
function build_iozone {
	echo "Building IOZONE..."
	cd ../../$IOZONE/src/current
	chmod a+w makefile
	DYNAMIC_STRING="-lrt -lpthread -o iozone"
	STATIC_REPLACE="-lrt -lpthread -o iozone -static"
	sed -i "s/${DYNAMIC_STRING}/${STATIC_REPLACE}/g" makefile
	chmod a-w makefile
	make linux-AMD64 -s > /dev/null 2> /dev/null 
	catch_and_report_error $? -3 "make linux-AMD64 -> IOZONE"

	cp -a ./iozone ../../../out/initramfs-x86/testing/
	cd ../../../$OUT
	echo "find . -print0 | cpio --null -ov --format=newc | gzip -9 > ../initramfs-busybox-x86.cpio.gz" > generate_initramfs.sh

	cd initramfs-x86
	. ../generate_initramfs.sh > /dev/null 2> /dev/null
	echo -e "Done.\n"
}
#=================Kernel======================
function build_kernel {
	echo "Preparing for Linux Kernel building..." 
	cd ../../$LINUX_KERNEL
	mkdir -p ../out/kernel
	make O=../out/kernel mrproper -s > /dev/null 2> /dev/null
	catch_and_report_error $? -3 "make mrproper -> Kernel"
	make O=../obj/linux-x86-basic x86_64_defconfig -s > /dev/null 2> /dev/null
	catch_and_report_error $? -3 "make x86_64_defconfig -> Kernel"
	echo "Configuring Kernel..."
	echo
	echo "Another menu will now open, "
	echo -e "# config options - change the following settings and save '.config'\n
	#\n
	#     -> General setup\n
	#        -> Local version - append to kernel release\n
	#            set to 'example1'\n
	#\n
	#    -> Device drivers\n
	#        <*> MMC/SD/SDIO card support\n
	#            <*>   MMC block device driver\n
	#            <*>   Secure Digital Host Controller Interface support\n
	#            <*>   SDHCI support on PCI bus\n
	#\n
	#    -> File systems\n
	#        -*- Miscellaneous filesystems\n
	#            <*>   F2FS filesystem support (EXPERIMENTAL)\n
	#\n
	#    -> Kernel hacking\n
	#        [*] Compile the kernel with frame pointers\n
	#        [*] Compile the kernel with debug info\n
	#        [*] KGDB: kernel debugger\n
	#            <*>   KGDB: use kgdb over the serial console\n
	#\n"
	make O=../out/kernel menuconfig -s 2> /dev/null
	catch_and_report_error $? -3 "make menuconfig -> Kernel"
	echo 
	echo "Building Kernel..."
	echo
	echo "info: Kernel building process can be optimized by using multiple cores, how many cores do you want to use?"
	echo "WARNING: It is not recommended to choose a number more than physical cores."
	read cores
	echo
	echo "Building Started..."
	echo
	make -j$cores O=../out/kernel -s > /dev/null 2> /dev/null
	catch_and_report_error $? -3 "make -> Kernel"
	echo "Done Building the kernel."
	echo
}
#=================QEMU======================
function build_qemu {
	echo "Building QEMU..."
	cd ../$QEMU
	mkdir ../out/qemu-build
	cd ../out/qemu-build
	echo -e "\nConfiguring QEMU to build a x86_64 target..."
	../../$QEMU/configure --target-list=x86_64-softmmu --prefix="$PWD/../qemu-out" > /dev/null
	echo -e "\nBuilding started...\n"
	echo "info: QEMU building process can be optimized by using multiple cores, how many cores do you want to use?"
	echo "WARNING: It is not recommended to choose a number more than physical cores."
	read cores
	make -j$cores > /dev/null 2> /dev/null
	catch_and_report_error $? -3 "make -> QEMU"
	make -j$cores install -s > /dev/null 2> /dev/null
	catch_and_report_error $? -3 "make install -> QEMU"
	echo -e "\nDone building QEMU."
}



#=====================MAIN=====================
echo
echo "Starting to build linux on QEMU environment..."
echo "Please specify build TOP Directory: (Example: PATH/\$TOP_DIRECTORY)"
#Reading the path for TOP Directory
read -e DIR
if [[ ! -d $DIR ]]; then
	echo "Directory does not exist, creating directory..."
	mkdir -p "$DIR"
	catch_and_report_error $? -4 "Entry"
fi
#Set Current directory to desired TOP Directory
cd $DIR
#Start Downloading the archives
download_archives
#Extract archives in TOP directory
extract_archives
#Check packages
check_packages
#Start building BusyBox
build_busybox
#Start building IOZONE
build_iozone
#Start building Kernel
build_kernel
#Start building QEMU
build_qemu
#Start Testing Builds
cd $DIR
echo -e "\nTesting builds...\n"
#Testing BusyBox
test_busybox
#Testing IOZONW
test_iozone
#Testing QEMU
test_qemu
#This will only print if all tests are successfull
echo -e "All tests passed!"
