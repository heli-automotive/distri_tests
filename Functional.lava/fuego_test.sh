tarball=releng-scripts.tar.gz

# phase "pre_test" should be skipped for lava test, because the target boards might:
# - the target is not connected to Fuego and in power off status.
FUEGO_TEST_PHASES="pre_check build deploy run processing"
FUNCTIONAL_LAVA_PER_JOB_BUILD=true
source /fuego-ro/boards/$NODE_NAME.lava

#TODO: test_pre_check should be called outside pre_test?
function test_pre_check {
    # phase "pre_test" is skipped, so we need to set the following env variables manually.
    # TODO: source toolchain.sh outside phase "pre_test" and get the FWVER from LAVA outputs
    export PLATFORM="unknow"
    export FWVER="unknow"

    assert_define LAVA_USER
    assert_define LAVA_HOST

    which lava-tool > /dev/null || echo "Warning: lava-tool missing in your test framework."

    #echo "default keyring config"
    if [ ! -d ~/.local/share/python_keyring/ ] ; then
        rm -rf ~/.local/share/python_keyring/ || true
        mkdir -p ~/.local/share/python_keyring/
    fi

    cat <<EOF >  ~/.local/share/python_keyring/keyringrc.cfg
[backend]
default-keyring=keyring.backends.file.PlaintextKeyring
EOF

    cat <<EOF > ./token
$LAVA_TOKEN
EOF

    lava-tool auth-add --token-file ./token http://${LAVA_USER}@${LAVA_HOST}
    rm ./token
}

function test_build {
    [ -n "$FUNCTIONAL_LAVA_FILE_SERVER" ] || FUNCTIONAL_LAVA_FILE_SERVER=$DEFAULT_FILE_SERVER
    [ -n "$FUNCTIONAL_LAVA_BOOT_TYPE" ] || FUNCTIONAL_LAVA_BOOT_TYPE=$DEFAULT_LAVA_BOOT_TYPE

    JOB_OPTS="--test health-test"
    [ -n $LAVA_MACHINE_TYPE ] && JOB_OPTS="${JOB_OPTS} --machine $LAVA_MACHINE_TYPE" \
                              || abort_job "Please define LAVA_MACHINE_TYPE in your lava board file."
    [ -n "$FUNCTIONAL_LAVA_BOOT_TYPE" ] && JOB_OPTS="${JOB_OPTS} --boot ${FUNCTIONAL_LAVA_BOOT_TYPE}"
    [ -n "$FUNCTIONAL_LAVA_FILE_SERVER" ] && JOB_OPTS="${JOB_OPTS} --url $FUNCTIONAL_LAVA_FILE_SERVER"

    #TODO: add more options, e.g. to use --kernel-img to specify the name of the kernel to boot
    echo "Job creation: ./utils/create-jobs.py ${JOB_OPTS}"
    ./utils/create-jobs.py ${JOB_OPTS} > test.yaml

    if [ -n "$FUNCTIONAL_LAVA_TESTSUITE_REPO" -a -n "$FUNCTIONAL_LAVA_TESTSUITE_PATH" ]; then
        echo "-test:" >> test.yaml
        echo "    definitions:" >> test.yaml
        echo "    - repository: $FUNCTIONAL_LAVA_TESTSUITE_REPO" >> test.yaml
        echo "      from: git" >> test.yaml
        echo "      path: $FUNCTIONAL_LAVA_TESTSUITE_PATH" >> test.yaml
        echo "      name: ${FUNCTIONAL_LAVA_TESTSUITE_NAME:-default-tests}" >> test.yaml
    fi

    # TODO: add support to validate the definition of test.yaml.
}

function test_deploy {
    echo "test_deploy finished successfully."
}

function test_run {
    LAVA_JOB_ID=0
    LAVA_JOB_STATUS="Submitted"

    #  It will be more flexible if not using "lava-tool block" here.
    echo "lava-tool: submit-job test.yaml to $LAVA_HOST with user($LAVA_USER)..."
    lava-tool submit-job http://$LAVA_USER@$LAVA_HOST test.yaml | tee tmp_submit.txt
    LAVA_JOB_ID=`cat tmp_submit.txt | grep -i "job id" | awk '{print $5}' | tr -d '\r'`

    while [[ "$LAVA_JOB_STATUS" =~ "Submitted" || "$LAVA_JOB_STATUS" =~ "Running" ]]; do
        sleep 5
        lava-tool job-status http://$LAVA_USER@$LAVA_HOST $LAVA_JOB_ID > tmp_status.txt
        LAVA_JOB_STATUS=`cat tmp_status.txt | grep "Job Status" | awk '{print $3}' | tr -d '\r'`

        [[ "$LAVA_JOB_STATUS" =~ "Submitted" ]] && continue

        lava-tool job-output http://$LAVA_USER@$LAVA_HOST $LAVA_JOB_ID --overwrite > tmp_output.txt
        if [ -f $LAVA_JOB_ID\_output.txt ]; then
            if [ -f $LAVA_JOB_ID\_output.txt.ori ]; then
                diff $LAVA_JOB_ID\_output.txt $LAVA_JOB_ID\_output.txt.ori \
                     | grep -v "\"results\"" | awk -F '"' '{print "LAVA>> "$12}'
            else
                cat $LAVA_JOB_ID\_output.txt | grep -v "\"results\"" | awk -F '"' '{print "LAVA>> "$12}'
            fi
            mv $LAVA_JOB_ID\_output.txt $LAVA_JOB_ID\_output.txt.ori
        fi
    done

    if [ ! -f ${LOGDIR}/testlog.txt ]; then
        echo "generate ${LOGDIR}/testlog.txt..."
        [ -f $LAVA_JOB_ID\_output.txt.ori  ] && mv $LAVA_JOB_ID\_output.txt.ori ${LOGDIR}/testlog.txt
    fi
}

function test_processing {
    # TODO: get more useful outputs from LAVA side
    log_compare "$TESTDIR" "0" "OK" "p"
}
