#!/bin/bash

set -e

export ANSI_YELLOW_BOLD="\e[1;33m"
export ANSI_GREEN="\e[32m"
export ANSI_YELLOW_BACKGROUND="\e[1;7;33m"
export ANSI_GREEN_BACKGROUND="\e[1;7;32m"
export ANSI_CYAN_BACKGROUND="\e[1;7;36m"
export ANSI_CYAN="\e[36m"
export ANSI_RESET="\e[0m"
export DOCKERFILE_TOP="**************************************** DOCKERFILE ******************************************"
export DOCKERFILE_BOTTOM="**********************************************************************************************"
export TEST_SUITE_START="**************************************** SMOKE TESTS *****************************************"
export TEST_SUITE_END="************************************** TEST SUCCESSFUL ***************************************"

# Pass in path to folder where Dockerfile lives
print_dockerfile () {
        echo -e "\n$ANSI_CYAN$DOCKERFILE_TOP\n$(<$1/Dockerfile)\n$ANSI_CYAN$DOCKERFILE_BOTTOM $ANSI_RESET\n"
}

# Pass in test case message
print_test_case () {
        echo -e "\n$ANSI_YELLOW_BOLD$1 $ANSI_RESET"
}

print_success () {
        echo -e "\n$ANSI_GREEN$1 $ANSI_RESET \n"

}

wait_until_ready () {
        export SECONDS=$1
        export SLEEP_INTERVAL=$(echo $SECONDS 50 | awk '{ print $1/$2 }')

        echo -e "\n${ANSI_CYAN}Waiting ${SECONDS} seconds until ready: ${ANSI_RESET}"

        for second in {1..50}
        do
                echo -ne "${ANSI_CYAN_BACKGROUND} ${ANSI_RESET}"
                sleep ${SLEEP_INTERVAL}
        done

        echo -e "${ANSI_CYAN} READY${ANSI_RESET}"
}


# Pass in path to folder where Dockerfile lives
build () {
        print_dockerfile $1
        docker build -t $1 $1
}

cleanup () {
        docker rmi $1
}

suite_start () {
        echo -e "\n$ANSI_YELLOW_BACKGROUND$TEST_SUITE_START$ANSI_RESET \n"
}

suite_end () {
        echo -e "\n$ANSI_GREEN_BACKGROUND$TEST_SUITE_END$ANSI_RESET \n"
}


suite_start
        print_test_case "It starts successfully:"
                build "configured-clair-scanner"
                docker run --name clair-db -p 5432:5432 -e POSTGRES_PASSWORD=password -d quay.io/ibmz/postgres:13
                wait_until_ready 5
                docker run --name configured-clair-scanner -d -p 6060-6061:6060-6061 "configured-clair-scanner" -config=/config/config.yaml
                wait_until_ready 30
                curl --fail -X GET -I http://9.12.41.89:6061/health | grep 200
                print_success "Success! Clair is running and healthy"
                
        print_test_case "It provides information about image vulnerabilities."
                wait_until_ready 400
                curl --fail -X GET -I http://9.12.41.89:6060/v1/namespaces/debian:10/vulnerabilities?limit=2 | grep 200
                print_success "Success! Clair is providing information about image vulnerabilities."
                docker rm -f configured-clair-scanner
                docker rm -f clair-db
                cleanup "configured-clair-scanner"
suite_end
