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
    source /usr/local/greenplum-clients-devel/greenplum_clients_path.sh
    psql --version
    chown -R gpadmin:gpadmin /usr/local/greenplum-clients-devel
}

function gen_env(){
  cat > /opt/run_test.sh <<-EOF
		source /usr/local/greenplum-db-devel/greenplum_path.sh
		cd "\${1}/gpdb_src"
		source gpAux/gpdemo/gpdemo-env.sh
		source /usr/local/greenplum-clients-devel/greenplum_clients_path.sh
		cd "\${1}/gpdb_md5_src/src/test/authentication"
		make check
		if [ $? -ne 0]
		then
				echo "test 001_password.pl failed"
		fi
		cd "\${1}/gpdb_md5_src/src/test/ssl"
		make check
		if [ $? -ne 0]
		then
				echo "test 001_password.pl failed"
		fi
		cd "\${1}/gpdb_md5_src/src/test/regress"
		./pg_regress  --init-file=init_file password
		[ -s regression.diffs ] && cat regression.diffs && exit 1
		exit 0
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
    time gen_env
    time run_test
}

_main "$@"
