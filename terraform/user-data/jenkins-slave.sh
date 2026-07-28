#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y openjdk-17-jdk docker.io awscli curl jq

systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu

useradd -m -s /bin/bash jenkins
usermod -aG docker jenkins

mkdir -p /home/jenkins
chown -R jenkins:jenkins /home/jenkins

REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)

for i in $(seq 1 30); do
    MASTER_URL=$(aws ssm get-parameter \
        --name "/${project_name}/jenkins-master-url" \
        --query "Parameter.Value" \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    if [ -n "$MASTER_URL" ] && [ "$MASTER_URL" != "None" ]; then
        break
    fi
    echo "Waiting for Jenkins master URL..."
    sleep 20
done

if [ -z "$MASTER_URL" ] || [ "$MASTER_URL" = "None" ]; then
    echo "Failed to discover Jenkins master URL"
    exit 1
fi

cat > /etc/systemd/system/jenkins-agent.service << SERVICE
[Unit]
Description=Jenkins Agent
After=network.target

[Service]
User=jenkins
Group=jenkins
WorkingDirectory=/home/jenkins
Environment="JENKINS_URL=$${MASTER_URL}"
ExecStartPre=/usr/bin/curl -s -o /home/jenkins/agent.jar $${JENKINS_URL}/jnlpJars/agent.jar
ExecStart=/usr/bin/java -jar /home/jenkins/agent.jar -jnlpUrl $${JENKINS_URL}/computer/slave/slave-agent.jnlp -secret "" -workDir "/home/jenkins"
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable jenkins-agent
systemctl start jenkins-agent
