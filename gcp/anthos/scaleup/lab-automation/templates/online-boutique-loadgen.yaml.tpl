---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: loadgenerator
spec:
  selector:
    matchLabels:
      app: loadgenerator
  replicas: 1
  template:
    metadata:
      labels:
        app: loadgenerator
      annotations:
        sidecar.istio.io/rewriteAppHTTPProbers: "true"
    spec:
      serviceAccountName: default
      terminationGracePeriodSeconds: 5
      restartPolicy: Always
      initContainers:
      - command:
        - /bin/sh
        - -exc
        - |
          echo "Init container pinging frontend: $${FRONTEND_ADDR}..."
          STATUSCODE=$(wget --server-response http://$${FRONTEND_ADDR} 2>&1 | awk '/^  HTTP/{print $2}')
          if test $STATUSCODE -ne 200; then
              echo "Error: Could not reach frontend - Status code: $${STATUSCODE}"
              exit 1
          fi
        name: frontend-check
        image: busybox:latest
        env:
        - name: FRONTEND_ADDR
          value: "${demo_app_url}"
      containers:
      - name: main
        image: gcr.io/google-samples/microservices-demo/loadgenerator:v0.2.4
        command: 
        - /bin/bash
        - -exc 
        - |
          echo "${external_vip} ${demo_app_url}" >> /etc/hosts && locust --host="http://$${FRONTEND_ADDR}" --headless -u "$${USERS:-10}" 2>&1
        env:
        - name: FRONTEND_ADDR
          value: "${demo_app_url}"
        - name: USERS
          value: "10"
        resources:
          requests:
            cpu: 300m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi