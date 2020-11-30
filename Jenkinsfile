pipeline {
  agent any
  options {
    parallelsAlwaysFailFast()
  }

  environment {
    // configure build params
    CI_BUILD_TAG = env.BUILD_TAG.replaceAll('%2f','').replaceAll('[^A-Za-z0-9]+', '').toLowerCase()
    SAFEBRANCH_NAME = env.BRANCH_NAME.replaceAll('%2f','-').replaceAll('[^A-Za-z0-9]+', '-').toLowerCase()
    // make will synchronise (buffer) output by default to avoid interspersed
    // lines from multiple jobs run in parallel. However this means that output for
    // each make target is not written until the command completes.
    //
    // See `man -P 'less +/-O' make` for more information about this option.
    //
    // Set to 'none' to disable output synchronisation.
    SYNC_MAKE_OUTPUT = 'target'
  }

  stages {
    stage ('env') {
      steps {
        sh 'env'
      }
    }
    // in order to have the newest images from upstream (with all the security updates) we clean our local docker cache on tag deployments
    // we don't do this all the time to still profit from image layer caching
    // but we want this on tag deployments in order to ensure that we publish images always with the newest possible images.
    stage ('clean docker image cache') {
      when {
        buildingTag()
      }
      steps {
        sh script: "docker image prune -af", label: "Pruning images"
      }
    }
    stage ('check PR labels') {
      when {
        changeRequest()
      }
      steps {
        script {
          pullRequest.labels.each {
            echo "This PR has labels: $it"
          }
        }
      }
    }
    stage ('build images') {
      steps {
        sh script: "make -O${SYNC_MAKE_OUTPUT} -j8 build", label: "Building images"
      }
    }
    stage ('push images to testlagoon/*') {
      when {
        not {
          environment name: 'SKIP_IMAGE_PUBLISH', value: 'true'
        }
      }
      environment {
        PASSWORD = credentials('amazeeiojenkins-dockerhub-password')
      }
      steps {
        sh script: 'docker login -u amazeeiojenkins -p $PASSWORD', label: "Docker login"
        sh script: "make -O${SYNC_MAKE_OUTPUT} -j8 publish-testlagoon-baseimages publish-testlagoon-serviceimages publish-testlagoon-taskimages BRANCH_NAME=${SAFEBRANCH_NAME}", label: "Publishing built images"
      }
    }
    stage ('run test suite') {
      steps {
        sh script: "echo make -O${SYNC_MAKE_OUTPUT} -j8 kind/test", label: "Running tests on kind cluster"
      }
    }
    stage ('push images to testlagoon/* with :latest tag') {
      when {
        branch 'main'
      }
      environment {
        PASSWORD = credentials('amazeeiojenkins-dockerhub-password')
      }
      steps {
        sh script: 'docker login -u amazeeiojenkins -p $PASSWORD', label: "Docker login"
        sh script: "echo make -O${SYNC_MAKE_OUTPUT} -j8 publish-testlagoon-baseimages publish-testlagoon-serviceimages publish-testlagoon-taskimages BRANCH_NAME=latest", label: "Publishing built images with :latest tag"
      }
    }
    stage ('push images to uselagoon/*') {
      when {
        buildingTag()
      }
      environment {
        PASSWORD = credentials('amazeeiojenkins-dockerhub-password')
      }
      steps {
        sh script: 'docker login -u amazeeiojenkins -p $PASSWORD', label: "Docker login"
        sh script: "echo make -O${SYNC_MAKE_OUTPUT} -j8 publish-uselagoon-baseimages publish-uselagoon-serviceimages publish-uselagoon-taskimages", label: "Publishing built images to uselagoon"
      }
    }
    stage ('deploy to test environment') {
      when {
        branch 'main'
      }
      environment {
        TOKEN = credentials('vshn-gitlab-helmfile-ci-trigger')
      }
      steps {
        sh script: "echo curl -X POST -F token=$TOKEN -F ref=master https://git.vshn.net/api/v4/projects/1263/trigger/pipeline", label: "Trigger lagoon-core helmfile sync on amazeeio-test6"
      }
    }
  }

  post {
    success {
      sh "echo SUCCESS"
    }
    failure {
      sh "echo FAILED"
    }
    cleanup {
      sh "echo make kind/cleanall"
      sh "make clean"
      sh "date"
    }
  }
}

def notifySlack(String buildStatus = 'STARTED') {
    // Build status of null means success.
    buildStatus = buildStatus ?: 'SUCCESS'

    def color

    if (buildStatus == 'STARTED') {
        color = '#68A1D1'
    } else if (buildStatus == 'SUCCESS') {
        color = '#BDFFC3'
    } else if (buildStatus == 'UNSTABLE') {
        color = '#FFFE89'
    } else {
        color = '#FF9FA1'
    }

    def msg = "${buildStatus}: `${env.JOB_NAME}` #${env.BUILD_NUMBER}:\n${env.BUILD_URL}"

    slackSend(color: color, message: msg)
}
