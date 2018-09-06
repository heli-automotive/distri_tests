tarball=releng-scripts.tar.gz

# phase "pre_test" should be skipped for lava test, because the target boards might:
# - the target is not connected to Fuego and in power off status.
FUEGO_TEST_PHASES="pre_check build deploy run processing"
FUNCTIONAL_LAVA_PER_JOB_BUILD=true
source /fuego-ro/boards/$NODE_NAME.lava

function test_pre_check {
    # the "pre_test" was skipped, so we need to set the following env variables manually.
    export PLATFORM="unknow"
    export FWVER="unknow"
    export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    unset PYTHONHOME

    which lava-tool || echo "Warning: lava-tool missing in your test framework."
    # add some check for lava-tool and lava-tool auth-list/token/passwd/etc.

    #echo "default keyring config"
    if [ ! -d ~/.local/share/python_keyring/ ] ; then
        rm -rf ~/.local/share/python_keyring/ || true
        mkdir -p ~/.local/share/python_keyring/
    fi

    cat <<EOF >  ~/.local/share/python_keyring/keyringrc.cfg
[backend]
default-keyring=keyring.backends.file.PlaintextKeyring
EOF

    assert_define LAVA_USER
    assert_define LAVA_HOST

    # auth .... should better be done with jenkins auth injection plugin ...
    cat <<EOF > ./token
$LAVA_TOKEN
EOF

    lava-tool auth-add --token-file ./token http://${LAVA_USER}@${LAVA_HOST}
    rm ./token
}

function test_build {
    # to use "ftc" tool to build and make tar for other tests, e.g. Functional.bc.
    # generate lava yaml test file.

    [ -n "$FUNCTIONAL_LAVA_FILE_SERVER" ] || FUNCTIONAL_LAVA_FILE_SERVER=$DEFAULT_FILE_SERVER
    if [ -n "$FUNCTIONAL_LAVA_FILE_SERVER" ]; then
        sed -i.bak "s@http://download.automotivelinux.org/AGL/release/eel/5.0.0/@${FUNCTIONAL_LAVA_FILE_SERVER}@g" templates/config/default.cfg
        sed -i.bak "s@http://download.automotivelinux.org/AGL/release/dab/4.0.2/@${FUNCTIONAL_LAVA_FILE_SERVER}@g" templates/config/default.cfg
        sed -i.bak "s@http://download.automotivelinux.org/AGL/release/@${FUNCTIONAL_LAVA_FILE_SERVER}@g" templates/config/default.cfg
        sed -i.bak "s@http://download.automotivelinux.org/AGL/snapshots/@${FUNCTIONAL_LAVA_FILE_SERVER}@g" templates/config/default.cfg
        sed -i.bak "s@http://download.automotivelinux.org/AGL/upload/ci/@${FUNCTIONAL_LAVA_FILE_SERVER}@g" templates/config/default.cfg
    fi

    # -u(--url) https://download-images-url
    [ -n "$FUNCTIONAL_LAVA_BOOT_TYPE" ] || FUNCTIONAL_LAVA_BOOT_TYPE=$DEFAULT_LAVA_BOOT_TYPE
    ./utils/create-jobs.py --machine $LAVA_MACHINE_TYPE --test health-test --boot ${FUNCTIONAL_LAVA_BOOT_TYPE} > test.yaml

    if [ -n "$FUNCTIONAL_LAVA_TESTSUITE_REPO" –a –n "$FUNCTIONAL_LAVA_TESTSUITE_PATH" ]; then
        echo "-test:" >> test.yaml
        echo "    definitions:" >> test.yaml
        echo "    - repository: $FUNCTIONAL_LAVA_TESTSUITE_REPO" >> test.yaml
        echo "      from: git" >> test.yaml
        echo "      path: $FUNCTIONAL_LAVA_TESTSUITE_PATH" >> test.yaml
        echo "      name: ${FUNCTIONAL_LAVA_TESTSUITE_NAME:-default-tests}" >> test.yaml
    fi
}

function test_deploy {
    # this step will be done in LAVA side.
    # no need to check the test_deploy status.
    echo "test_deploy finished successfully."
}

function test_run {
    LAVA_JOB_ID=0
    LAVA_JOB_STATUS="Submitted"

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
    # TODO: output analysis
    log_compare "$TESTDIR" "0" "OK" "p"
}
