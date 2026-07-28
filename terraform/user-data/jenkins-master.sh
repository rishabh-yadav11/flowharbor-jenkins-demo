#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y openjdk-17-jdk docker.io awscli curl jq

systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu

curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | tee /etc/apt/sources.list.d/jenkins.list > /dev/null
apt-get update -y
apt-get install -y jenkins

systemctl enable jenkins

TOKEN=$(openssl rand -base64 16)

mkdir -p /var/lib/jenkins/init.groovy.d

cat > /var/lib/jenkins/init.groovy.d/01-setup.groovy << 'GROOVY_EOF'
import jenkins.model.*
import hudson.security.*
import jenkins.install.*

def instance = Jenkins.getInstance()
instance.setInstallState(InstallState.INITIAL_SETUP_COMPLETED)

def env = System.getenv()
def adminPassword = env['JENKINS_ADMIN_PASSWORD'] ?: 'admin'

def hudsonRealm = new HudsonPrivateSecurityRealm(false)
hudsonRealm.createAccount('admin', adminPassword)
instance.setSecurityRealm(hudsonRealm)

def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
strategy.setAllowAnonymousRead(false)
instance.setAuthorizationStrategy(strategy)

instance.save()
GROOVY_EOF

cat > /var/lib/jenkins/init.groovy.d/02-plugins.groovy << 'GROOVY_EOF'
import jenkins.model.*
import java.util.logging.Logger

def instance = Jenkins.getInstance()
def pm = instance.getPluginManager()
def uc = instance.getUpdateCenter()
uc.updateAllSites()

def plugins = [
    "workflow-aggregator",
    "git",
    "pipeline-aws",
    "docker-workflow",
    "cloudbees-folder",
    "blueocean",
    "credentials-binding",
    "configuration-as-code"
]

plugins.each { plugin ->
    if (!pm.getPlugin(plugin)) {
        def deployment = uc.getPlugin(plugin).deploy()
        deployment.get()
    }
}

instance.save()
GROOVY_EOF

chown -R jenkins:jenkins /var/lib/jenkins

mkdir -p /etc/systemd/system/jenkins.service.d/
cat > /etc/systemd/system/jenkins.service.d/override.conf << OVERRIDE
[Service]
Environment="JENKINS_ADMIN_PASSWORD=$${TOKEN}"
Environment="JAVA_OPTS=-Djenkins.install.runSetupWizard=false"
OVERRIDE

systemctl daemon-reload
systemctl start jenkins

aws ssm put-parameter \
    --name "/${project_name}/jenkins-admin-password" \
    --value "$${TOKEN}" \
    --type "SecureString" \
    --overwrite \
    --region $(curl -s http://169.254.169.254/latest/meta-data/placement/region)

aws ssm put-parameter \
    --name "/${project_name}/jenkins-master-url" \
    --value "http://$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4):8080" \
    --type "String" \
    --overwrite \
    --region $(curl -s http://169.254.169.254/latest/meta-data/placement/region)

sleep 60

API_TOKEN=$(curl -s -u "admin:$${TOKEN}" -X POST "http://localhost:8080/me/descriptorByName/jenkins.security.ApiTokenProperty/generateNewToken" \
    --data "newTokenName=init-token" 2>/dev/null | jq -r '.data.tokenValue' || echo "")

if [ -n "$API_TOKEN" ]; then
    aws ssm put-parameter \
        --name "/${project_name}/jenkins-api-token" \
        --value "$${API_TOKEN}" \
        --type "SecureString" \
        --overwrite \
        --region $(curl -s http://169.254.169.254/latest/meta-data/placement/region)

    INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)

    SLAVE_IP=$(aws ec2 describe-instances \
        --region "$REGION" \
        --filters "Name=tag:Name,Values=${project_name}-jenkins-slave" "Name=instance-state-name,Values=running" \
        --query "Reservations[0].Instances[0].PrivateIpAddress" \
        --output text)

    if [ -n "$SLAVE_IP" ] && [ "$SLAVE_IP" != "None" ]; then
        curl -s -u "admin:$${API_TOKEN}" -X POST "http://localhost:8080/computer/doCreateItem" \
            --data "name=slave" \
            --data "type=hudson.slaves.DumbSlave" \
            --data-urlencode "json={\"name\":\"slave\",\"type\":\"hudson.slaves.DumbSlave\",\"launcher\":{\"stapler-class\":\"hudson.slaves.JNLPLauncher\"},\"remoteFS\":\"/home/jenkins\",\"numExecutors\":2,\"retentionStrategy\":{\"stapler-class\":\"hudson.slaves.RetentionStrategy\$Always\"}}" \
            2>/dev/null || true
    fi

    curl -s -u "admin:$${API_TOKEN}" -X POST "http://localhost:8080/createItem?name=flowharbor-pipeline" \
        --header "Content-Type: application/xml" \
        --data "<flow-definition plugin=\"workflow-job@2.40\">\
          <description>FlowHarbor CI/CD Pipeline</description>\
          <keepDependencies>false</keepDependencies>\
          <properties>\
            <parameters>\
              <hudson.model.ChoiceParameterDefinition>\
                <name>ENV</name>\
                <choices class=\"java.util.Arrays\">\
                  <a class=\"string-array\">\
                    <string>dev</string>\
                    <string>staging</string>\
                    <string>prod</string>\
                  </a>\
                </choices>\
              </hudson.model.ChoiceParameterDefinition>\
            </parameters>\
          </properties>\
          <definition class=\"org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition\">\
            <scm class=\"hudson.plugins.git.GitSCM\">\
              <userRemoteConfigs>\
                <hudson.plugins.git.UserRemoteConfig>\
                  <url>https://github.com/placeholder/flowharbor-app.git</url>\
                </hudson.plugins.git.UserRemoteConfig>\
              </userRemoteConfigs>\
              <branches>\
                <hudson.plugins.git.BranchSpec>\
                  <name>*/main</name>\
                </hudson.plugins.git.BranchSpec>\
              </branches>\
            </scm>\
            <scriptPath>Jenkinsfile</scriptPath>\
            <lightweight>true</lightweight>\
          </definition>\
          <triggers/>\
          <disabled>false</disabled>\
        </flow-definition>" \
        2>/dev/null || true
fi
