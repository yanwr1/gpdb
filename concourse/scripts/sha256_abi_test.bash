#!/bin/bash -l

set -eox pipefail

CWDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${CWDIR}/common.bash"

function setup_gpadmin_user() {
    ./gpdb_src/concourse/scripts/setup_gpadmin_user.bash "$TEST_OS"
}

function install_gpdb_clients() {
    mkdir -p /usr/local/greenplum-clients-devel
    tar -xzf bin_gpdb_clients/bin_gpdb_clients.tar.gz -C /usr/local/greenplum-clients-devel
    pushd /usr/local/greenplum-clients-devel
    source /usr/local/greenplum-clients-devel/greenplum_clients_path.sh
    psql --version
    chown -R gpadmin:gpadmin /usr/local/greenplum-clients-devel
    popd
}

function copy_test_case(){
    pushd gpdb_src
    rm -rf src/test/authentication/t/*
    cp ../tt_src/src/test/authentication/t/* src/test/authentication/t
    rm -rf src/test/ssl/t/*
    cp ../tt_src/src/test/ssl/t/* src/test/ssl/t
    popd
}

function gen_env(){
  cat > /opt/run_test.sh <<-EOF
		source /usr/local/greenplum-db-devel/greenplum_path.sh
		cd /usr/local/greenplum-clients-devel && source greenplum_clients_path.sh
		cp /usr/local/greenplum-clients-devel/bin/psql /usr/local/greenplum-db-devel/bin/
		cd "\${1}/gpdb_src"
		source gpAux/gpdemo/gpdemo-env.sh
		cd "\${1}/gpdb_src/src/test/regress"
		make
		cd "\${1}/gpdb_src/src/test/authentication"
		make check
		err1=\$?
		cd "\${1}/gpdb_src/src/test/ssl"
		make check
		err2=\$?
		cd "\${1}/gpdb_src/src/test/regress"
		./pg_regress  --init-file=init_file password
		[ -s regression.diffs ] && cat regression.diffs && exit 1
		exit \$err1 || \$err2
	EOF

	chmod a+x /opt/run_test.sh
}

function _main() {

    if [ -z "$TEST_OS" ]; then
            echo "FATAL: TEST_OS is not set"
            exit 1
    fi

    case "${TEST_OS}" in
    centos|ubuntu|sles) ;; #Valid
    *)
      echo "FATAL: TEST_OS is set to an invalid value: $TEST_OS"
      echo "Configure TEST_OS to be centos, or ubuntu"
      exit 1
      ;;
    esac

    time install_and_configure_gpdb
    time setup_gpadmin_user
    time make_cluster
    time install_gpdb_clients
    if [ "${COPY_TEST}" == "true" ]; then
	    time copy_test_case
    fi
    time gen_env
    time run_test
}

_main "$@"
