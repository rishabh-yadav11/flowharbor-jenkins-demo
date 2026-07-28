#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y openjdk-21-jdk-headless docker.io curl jq python3-pip

systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu

pip3 install awscli --break-system-packages

mkdir -p /home/ubuntu/jenkins-agent /var/jenkins
chown -R ubuntu:ubuntu /home/ubuntu/jenkins-agent /var/jenkins

REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)

for i in $(seq 1 30); do
    MASTER_URL=$(aws ssm get-parameter \
        --name "/${project_name}/jenkins-master-url" \
        --query "Parameter.Value" \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    AGENT_SECRET=$(aws ssm get-parameter \
        --name "/${project_name}/jenkins-slave-secret" \
        --with-decryption \
        --query "Parameter.Value" \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    if [ -n "$MASTER_URL" ] && [ "$MASTER_URL" != "None" ] && [ -n "$AGENT_SECRET" ] && [ "$AGENT_SECRET" != "None" ]; then
        break
    fi
    echo "Waiting for Jenkins master SSM params..."
    sleep 20
done

if [ -z "$MASTER_URL" ] || [ "$MASTER_URL" = "None" ]; then
    echo "Failed to discover Jenkins master URL"
    exit 1
fi

curl -sL -o /home/ubuntu/jenkins-agent/agent.jar "$MASTER_URL/jnlpJars/agent.jar" --max-time 30

cat > /etc/systemd/system/jenkins-agent.service << SERVICE
[Unit]
Description=Jenkins Agent Slave
After=network.target docker.service

[Service]
User=ubuntu
Group=ubuntu
WorkingDirectory=/home/ubuntu/jenkins-agent
ExecStart=/usr/bin/java -jar /home/ubuntu/jenkins-agent/agent.jar \
  -url $MASTER_URL \
  -secret $AGENT_SECRET \
  -name jenkins-slave \
  -workDir /var/jenkins
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable jenkins-agent
systemctl start jenkins-agent

echo "SLAVE_SETUP_COMPLETE"
