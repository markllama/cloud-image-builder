#!/usr/bin/env groovy
properties(
    [
        disableConcurrentBuilds(),
        buildDiscarder(
            logRotator(
                artifactDaysToKeepStr: '',
                artifactNumToKeepStr: '',
                daysToKeepStr: '',
                numToKeepStr: '5')),
        [
            $class: 'ParametersDefinitionProperty',
            parameterDefinitions: [
                [
                    name: 'GCP_CREDENTIALS',
                    description: '',
                    $class: 'hudson.model.StringParameterDefinition',
                    defaultValue: 'kubevirt-gcp-credentials-file'
                ],
                [
                    name: 'GCP_SSH_PRIVATE_KEY_FILE',
                    description: '',
                    $class: 'hudson.model.StringParameterDefinition',
                    defaultValue: 'kubevirt-gcp-ssh-private-key'
                ],
                [
                    name: 'GCP_SSH_PUBLIC_KEY_FILE',
                    description: '',
                    $class: 'hudson.model.StringParameterDefinition',
                    defaultValue: 'kubevirt-gcp-ssh-public-key'
                ],


                [
                    name: 'AWS_ACCESS_KEY_ID',
                    description: '',
                    $class: 'hudson.model.StringParameterDefinition',
                    defaultValue: 'kubevirt-aws-access-key-id'
                ],
                [
                    name: 'AWS_SECRET_ACCESS_KEY',
                    description: '',
                    $class: 'hudson.model.StringParameterDefinition',
                    defaultValue: 'kubevirt-aws-secret-access-key'
                ],
                [
                    name: 'AWS_SUBNET_ID_CRED',
                    description: '',
                    $class: 'hudson.model.StringParameterDefinition',
                    defaultValue: 'kubevirt-aws-subnet-id'
                ],
                [
                    name: 'AWS_SECURITY_GROUP_ID_CRED',
                    description: '',
                    $class: 'hudson.model.StringParameterDefinition',
                    defaultValue: 'kubevirt-aws-security-group-id'
                ],
                [
                    name: 'AWS_SECURITY_GROUP_CRED',
                    description: '',
                    $class: 'hudson.model.StringParameterDefinition',
                    defaultValue: 'kubevirt-aws-security-group'
                ],
                [
                    name: 'AWS_KEY_NAME_CRED',
                    description: '',
                    $class: 'hudson.model.StringParameterDefinition',
                    defaultValue: 'kubevirt-aws-key-name'
                ],
                [
                    name: 'AWS_SSH_PRIVATE_KEY',
                    description: '',
                    $class: 'hudson.model.StringParameterDefinition',
                    defaultValue: 'kubevirt-aws-ssh-private-key'
                ],
            ]
        ]
    ]
)

def gcp_credentials = [
    sshUserPrivateKey(credentialsId: GCP_SSH_PRIVATE_KEY_FILE, keyFileVariable: 'SSH_KEY_LOCATION'),
    file(credentialsId: GCP_APP_CREDENTIALS, variable: 'GOOGLE_APPLICATION_CREDENTIALS'),
    file(credentialsId: GCP_SSH_PUBLIC_KEY_FILE, variable: 'GCP_SSH_PUBLIC_KEY')

]

def aws_credentials = [
    string(credentialsId: AWS_ACCESS_KEY_ID, variable: 'AWS_ACCESS_KEY_ID'),
    string(credentialsId: AWS_SECRET_ACCESS_KEY, variable: 'AWS_SECRET_ACCESS_KEY'),
    string(credentialsId: AWS_SUBNET_ID_CRED, variable: 'AWS_SUBNET_ID'),
    string(credentialsId: AWS_SECURIT_GROUP_ID_CRED, variable: 'AWS_SECURITY_GROUP_ID'),
    string(credentialsId: AWS_SECURIT_GROUP_CRED, variable: 'AWS_SECURITY_GROUP'),
    string(credentialsId: AWS_KEY_NAME_CRED, variable: 'AWS_KEY_NAME'),
    sshUserPrivateKey(credentialsId: AWS_SSH_PRIVATE_KEY, keyFileVariable: 'SSH_KEY_LOCATION')

]

def images = [
    'aws-centos': [
        'envFile': 'environment.aws',
        'credentials': aws_credentials
    ],
    'gcp-centos': [
        'envFile': 'environment.gcp',
        'credentials': gcp_credentials
    ]
]

builders = [:]

images.each { imageName, imageValues ->

    def podName = "${imageName}-${UUID.randomUUID().toString()}"

    builders[podName] = {

        def params = [:]
        def credentials = []

        def containers = ['ansible-executor': [tag: 'latest', privileged: false, command: 'uid_entrypoint cat']]


        def archives = {
            step([$class   : 'ArtifactArchiver', allowEmptyArchive: true,
                  artifacts: 'packer-build-*.json,published-aws-image-ids', fingerprint: true])
        }

        deployOpenShiftTemplate(containersWithProps: containers, openshift_namespace: 'kubevirt', podName: podName,
                                docker_repo_url: '172.30.254.79:5000', jenkins_slave_image: 'jenkins-contra-slave:latest') {

            ciPipeline(buildPrefix: 'kubevirt-image-builder', decorateBuild: decoratePRBuild(), archiveArtifacts: archives, timeout: 120) {

                try {

                    stage("prepare-environment-${imageName}") {
                        handlePipelineStep {
                            echo "STARTING BUILD OF - ${imageName}"
                            checkout scm
                            params = readProperties file: imageValues['envFile']
                            credentials = imageValues['credentials']

                            // modify any parameters
                            imageParam = env.TAG_NAME ?: (env.BRANCH_NAME ?: 'master')
                            imageParam = "${imageParam}-build-${env.BUILD_NUMBER}".replaceAll('\\.','-')
                            params['IMAGE_NAME'] = "${params['IMAGE_NAME']}-${imageParam.toLowerCase()}"
                        }
                    }

                    stage("build-image-${imageName}") {
                        def cmd = """
                        curl -L -o /tmp/packer.zip https://releases.hashicorp.com/packer/1.2.5/packer_1.2.5_linux_amd64.zip
                        unzip /tmp/packer.zip -d .
                        sh \${BUILD_SCRIPT}
                        """

                        executeInContainer(containerName: 'ansible-executor', containerScript: cmd, stageVars: params,
                                           credentials: credentials)

                    }

                    stage("test-image-${imageName}") {
                        def cmd = """
                        mkdir -p ~/.ssh
                        ansible-playbook -vvv --private-key \${SSH_KEY_LOCATION} \${PLAYBOOK}
                        """


                        executeInContainer(containerName: 'ansible-executor', containerScript: cmd, stageVars: params,
                                           loadProps: ["build-image-${imageName}"], credentials: credentials)
                    }

                    if (env['TAG_NAME']) {
                        stage("deploy-image-${imageName}") {
                            def cmd = """
                            ansible-playbook -vvv --private-key \${SSH_KEY_LOCATION} \${PLAYBOOK_DEPLOY}
                            """

                            executeInContainer(containerName: 'ansible-executor', containerScript: cmd, stageVars: params,
                                               loadProps: ["build-image-${imageName}"], credentials: credentials)
                        }
                    }

                } catch (e) {
                    echo e.toString()
                    throw e

                } finally {
                    stage("cleanup-image-${imageName}") {
                        def cmd = """
                        ansible-playbook -vvv --private-key \${SSH_KEY_LOCATION} \${PLAYBOOK_CLEANUP}
                        """

                        executeInContainer(containerName: 'ansible-executor', containerScript: cmd, stageVars: params,
                                           loadProps: ['build-image'], credentials: credentials)
                    }

                    echo "ENDING BUILD OF - ${imageName}"
                }
            }
        }
    }
}

parallel builders
