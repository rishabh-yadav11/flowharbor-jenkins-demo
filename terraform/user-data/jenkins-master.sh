#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive

IMDS_TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
imds() { curl -s -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" "http://169.254.169.254/latest/$1"; }
REGION=$(imds "meta-data/placement/region")
LOCAL_IP=$(imds "meta-data/local-ipv4")

apt-get update -y
apt-get install -y openjdk-21-jdk-headless docker.io curl jq python3-pip

systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu

pip3 install awscli --break-system-packages

mkdir -p /usr/share/jenkins
curl -fsSL https://get.jenkins.io/war-stable/2.452.3/jenkins.war -o /usr/share/jenkins/jenkins.war

id -u jenkins &>/dev/null || useradd -m -d /var/lib/jenkins -s /bin/bash jenkins
mkdir -p /var/lib/jenkins /var/log/jenkins /var/cache/jenkins
chown -R jenkins:jenkins /var/lib/jenkins /var/log/jenkins /var/cache/jenkins /usr/share/jenkins

ADMIN_PASS=$(openssl rand -base64 16)

cat > /etc/systemd/system/jenkins.service << UNIT
[Unit]
Description=Jenkins Continuous Integration Server
After=network.target

[Service]
User=jenkins
Group=jenkins
WorkingDirectory=/var/lib/jenkins
Environment=JENKINS_HOME=/var/lib/jenkins
Environment=JENKINS_ADMIN_PASSWORD=$ADMIN_PASS
ExecStart=/usr/bin/java -Djenkins.install.runSetupWizard=false -Xmx1024m -jar /usr/share/jenkins/jenkins.war --httpPort=8080
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
UNIT

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
def instance = Jenkins.getInstance()
def pm = instance.getPluginManager()
def uc = instance.getUpdateCenter()
uc.updateAllSites()
def plugins = [
    "workflow-aggregator", "git", "pipeline-aws", "docker-workflow",
    "cloudbees-folder", "blueocean", "credentials-binding",
    "configuration-as-code", "pipeline-input-step", "github"
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

systemctl daemon-reload
systemctl enable jenkins
systemctl start jenkins

aws ssm put-parameter \
    --name "/${project_name}/jenkins-admin-password" \
    --value "$ADMIN_PASS" \
    --type SecureString \
    --overwrite \
    --region "$REGION"

aws ssm put-parameter \
    --cli-input-json "{\"Name\":\"/${project_name}/jenkins-master-url\",\"Value\":\"http://$LOCAL_IP:8080\",\"Type\":\"String\",\"Overwrite\":true}" \
    --region "$REGION"

sleep 60

CJAR=/tmp/jc.txt
rm -f "$CJAR"
CRUMB=$(curl -s -c "$CJAR" -b "$CJAR" -u "admin:$ADMIN_PASS" \
  'http://localhost:8080/crumbIssuer/api/json' --max-time 10 | \
  python3 -c "import sys,json;print(json.load(sys.stdin)['crumb'])")

curl -s -u "admin:$ADMIN_PASS" -c "$CJAR" -b "$CJAR" \
  -H "Jenkins-Crumb: $CRUMB" \
  -X POST 'http://localhost:8080/scriptText' \
  --data-urlencode 'script=import jenkins.model.*;def i=Jenkins.getInstance();i.setSlaveAgentPort(50000);i.save()' \
  --max-time 10

curl -s -u "admin:$ADMIN_PASS" -c "$CJAR" -b "$CJAR" \
  -H "Jenkins-Crumb: $CRUMB" \
  -X POST 'http://localhost:8080/scriptText' \
  --data-urlencode 'script=import jenkins.model.*;import hudson.slaves.*;def i=Jenkins.getInstance();def n=i.getNode("jenkins-slave");if(n){i.removeNode(n)};def s=new DumbSlave("jenkins-slave","/var/jenkins",null);s.setNumExecutors(2);s.setLabelString("docker linux");s.setMode(hudson.model.Node.Mode.NORMAL);s.setRetentionStrategy(new RetentionStrategy.Always());s.setLauncher(new JNLPLauncher());i.addNode(s);i.save()' \
  --max-time 10

AGENT_SECRET=$(curl -s -u "admin:$ADMIN_PASS" -c "$CJAR" -b "$CJAR" \
  -H "Jenkins-Crumb: $CRUMB" \
  -X POST 'http://localhost:8080/scriptText' \
  --data-urlencode 'script=import jenkins.model.*;for(c in Jenkins.getInstance().computers){if(c.name=="jenkins-slave"){print(c.getJnlpMac())}}' \
  --max-time 10)

aws ssm put-parameter \
    --name "/${project_name}/jenkins-slave-secret" \
    --value "$AGENT_SECRET" \
    --type SecureString \
    --overwrite \
    --region "$REGION"

# Create pipeline job via Groovy
curl -s -u "admin:$ADMIN_PASS" -c "$CJAR" -b "$CJAR" \
  -H "Jenkins-Crumb: $CRUMB" \
  -X POST 'http://localhost:8080/scriptText' \
  --data-urlencode 'script=import jenkins.model.*;import org.jenkinsci.plugins.workflow.job.WorkflowJob;import org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition;import hudson.plugins.git.GitSCM;import hudson.plugins.git.BranchSpec;import hudson.plugins.git.UserRemoteConfig;import com.cloudbees.jenkins.GitHubPushTrigger;def i=Jenkins.getInstance();def jn="flowharbor-pipeline";def ex=i.getItem(jn);if(ex){ex.delete()};def j=new WorkflowJob(i,jn);j.addTrigger(new GitHubPushTrigger());def scm=new GitSCM([new UserRemoteConfig("https://github.com/rishabh-yadav11/flowharbor-jenkins-demo.git",null,null,null)],[new BranchSpec("*/dev")],false,[],null,null,[]);j.setDefinition(new CpsScmFlowDefinition(scm,"Jenkinsfile"));i.add(j,jn);j.save();i.save();println("PIPELINE_CREATED")' \
  --max-time 10

# Store ECR URL as credential
curl -s -u "admin:$ADMIN_PASS" -c "$CJAR" -b "$CJAR" \
  -H "Jenkins-Crumb: $CRUMB" \
  -X POST 'http://localhost:8080/scriptText' \
  --data-urlencode 'script=import jenkins.model.*;import com.cloudbees.plugins.credentials.*;import com.cloudbees.plugins.credentials.domains.*;import org.jenkinsci.plugins.plaincredentials.impl.StringCredentialsImpl;import hudson.util.Secret;def i=Jenkins.getInstance();def s=Domain.global();def p=CredentialsProvider.lookupStores(i).iterator().next();def id="ecr-repository-url";def ex=CredentialsProvider.lookupCredentials(StringCredentialsImpl.class,i).find({it.id==id});if(ex){p.removeCredentials(s,ex)};def c=new StringCredentialsImpl(CredentialsScope.GLOBAL,id,"ECR Repository URL",Secret.fromString("${ecr_repository_url}"));p.addCredentials(s,c);i.save();println("ECR_CRED_ADDED")' \
  --max-time 10

echo "MASTER_SETUP_COMPLETE"
