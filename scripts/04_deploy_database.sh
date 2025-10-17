#!/usr/bin/env bash

set -eo pipefail

echo "Deploying MySQL Operator..."
helm repo add mysql-operator https://mysql.github.io/mysql-operator/
helm repo update
helm install mysql-operator mysql-operator/mysql-operator --namespace mysql-operator --create-namespace

echo "Waiting for MySQL Operator to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/mysql-operator -n mysql-operator

echo "Deploying MySQL InnoDB Cluster..."
helm install my-mysql mysql-operator/mysql-innodbcluster \
    --set credentials.root.user='root' \
    --set credentials.root.password='mysecretPassword' \
    --set credentials.root.host='%' \
    --set serverInstances=1 \
    --set routerInstances=1 \
    --set tls.useSelfSigned=true

echo "Waiting for MySQL to be ready..."
kubectl wait --for=jsonpath='{.status.cluster.status}'=ONLINE --timeout=300s innodbcluster/my-mysql || true
sleep 10

echo "Creating todo database and user..."
kubectl exec my-mysql-0 -c mysql -- mysql -uroot -pmysecretPassword -e "CREATE DATABASE IF NOT EXISTS todo;"
kubectl exec my-mysql-0 -c mysql -- mysql -uroot -pmysecretPassword -e "CREATE USER IF NOT EXISTS 'todo'@'%' IDENTIFIED BY 'mysecretPassword';"
kubectl exec my-mysql-0 -c mysql -- mysql -uroot -pmysecretPassword -e "GRANT ALL PRIVILEGES ON todo.* TO 'todo'@'%';"
kubectl exec my-mysql-0 -c mysql -- mysql -uroot -pmysecretPassword -e "FLUSH PRIVILEGES;"

echo "Creating notification database and user..."
kubectl exec my-mysql-0 -c mysql -- mysql -uroot -pmysecretPassword -e "CREATE DATABASE IF NOT EXISTS notification;"
kubectl exec my-mysql-0 -c mysql -- mysql -uroot -pmysecretPassword -e "CREATE USER IF NOT EXISTS 'notification'@'%' IDENTIFIED BY 'mysecretPassword';"
kubectl exec my-mysql-0 -c mysql -- mysql -uroot -pmysecretPassword -e "GRANT ALL PRIVILEGES ON notification.* TO 'notification'@'%';"
kubectl exec my-mysql-0 -c mysql -- mysql -uroot -pmysecretPassword -e "FLUSH PRIVILEGES;"

echo "Creating otel monitoring user..."
kubectl exec my-mysql-0 -c mysql -- mysql -uroot -pmysecretPassword -e "CREATE USER IF NOT EXISTS 'otel'@'%' IDENTIFIED BY 'mysecretPassword';"
kubectl exec my-mysql-0 -c mysql -- mysql -uroot -pmysecretPassword -e "GRANT SELECT, PROCESS, REPLICATION CLIENT ON *.* TO 'otel'@'%';"
kubectl exec my-mysql-0 -c mysql -- mysql -uroot -pmysecretPassword -e "FLUSH PRIVILEGES;"

echo "MySQL databases deployed successfully!"
