#TODO: Fuego just supports local tarball(download tarball from web should be added)
tarball="https://git.kernel.org/pub/scm/utils/rt-tests/rt-tests.git/snapshot/rt-tests-1.3.tar.gz"

NEED_ROOT=1

function test_pre_check {
    assert_define BENCHMARK_BACKFIRE_PARAMS

    # Kernel version on a target machine is the same with in the toolchain/SDK.
    # This is needed for checking the linux-headers was installed on the
    # our toolchain or not
    target_kernel_release=$(cmd "uname -r")
    if [ -d "${SDKROOT}/lib/modules/${target_kernel_release}/build" ]; then
        export KERNELDIR="${SDKROOT}/lib/modules/${target_kernel_release}/build"
    elif [ -d "${SDKROOT}/usr/src/kernel/" ]; then
        export KERNELDIR="${SDKROOT}/usr/src/kernel/"
    else
        abort_job "Please install linux-headers to your toolchain/SDK"
    fi
    is_on_target insmod PROGRAM_INSMOD /sbin:/usr/sbin:/usr/local/sbin
    assert_define PROGRAM_INSMOD
    is_on_target rmmod PROGRAM_RMMOD /sbin:/usr/sbin:/usr/local/sbin
    assert_define PROGRAM_RMMOD

    if check_kconfig "CONFIG_RT_GROUP_SCHED=y"; then
        echo "WARNING: CONFIG_RT_GROUP_SCHED enabled in your kernel. Please check the RT"
        echo "settings in CGroup if this test failed with 'Unable to change scheduling policy'."
    fi
}

function test_build {
    patch -p1 -N -s < $TEST_HOME/../rt-tests/0001-Add-scheduling-policies-for-old-kernels.patch
    make NUMA=0 sendme

    # Build the backfire driver
    patch -p1 -N -s < $TEST_HOME/0001-backfire-Modify-including-libraries-for-supporting-m.patch
    patch -p1 -N -s < $TEST_HOME/0002-backfire-Fix-copying-data-to-and-from-userspace.patch
    cd ./src/backfire/ || abort_job "./src/backfire directory does not exist"

    # Avoid that toolchain does not handle compiler linker flags correctly.
    unset LDFLAGS
    # User "jenkins" should have the permisson to do the following commands.
    # If not, users/tester should run the following commands manually.
    if [ ! -f $KERNELDIR/scripts/basic/fixdep ]; then
        cd $KERNELDIR;
        make scripts || echo "Please run 'make scripts' in $KERNELDIR and do this test again."
        cd -
    fi

    make
    [ -f backfire.ko ] || abort_job "Cannot build backfire driver"
    cd ../../
}

function test_deploy {
    put sendme  $BOARD_TESTDIR/fuego.$TESTDIR/
    put ./src/backfire/backfire.ko $BOARD_TESTDIR/fuego.$TESTDIR/
}

function test_run {
    # sendme does not support a option for printing a summary only on exit.
    # So, We get the three lines at the end of the command's output as a
    # summary of the report.
    report "cd $BOARD_TESTDIR/fuego.$TESTDIR; insmod ./backfire.ko; ./sendme $BENCHMARK_BACKFIRE_PARAMS | tail -n 3"
}

function test_cleanup {
    cmd "rmmod backfire &> /dev/null"
}
